@tool
extends Node

const PPHTTPClient = preload("res://addons/planetary_processing/pp_editor_http_client.gd")
const Utils = preload("res://addons/planetary_processing/pp_utils.gd")
var SDKScript = preload("res://addons/planetary_processing/SDKNode.cs")

signal chunk_state_changed(chunk_id, new_state)
signal entity_state_changed(entity_id, new_state)
signal new_player_entity(entity_id, state)
signal new_chunk(chunk_id, state)
signal new_entity(entity_id, state)
signal player_authenticated(player_uuid)
signal player_authentication_error(err)
signal player_unauthenticated()
signal player_connected()
signal player_disconnected()
signal remove_chunk(chunk_id)
signal remove_entity(entity_id)


@export_category("Game Config")
var game_id = ''

var logged_in = false
var registered_entities = []
var registered_chunks = []
@export_range(64, 65536) var Chunk_Size: int = 64

# Player
@export var player_scene: PackedScene
# Chunk
@export var chunk_scene: PackedScene
# Entities: 
@export var scenes: Array[PackedScene] = []
# event callback
@export var server_to_client_node: Node

var scenes_map: Dictionary = {}

var csproj_reference_exists = false
var client = PPHTTPClient.new()
var player_is_connected = false
var player_uuid = null
var timer: Timer
var timer_wait_in_s = 10
var sdk_node

func _ready():
    if Engine.is_editor_hint():
        return
    assert(
        game_id != "",
        "Planetary Processing Game ID not configured"
    )
    # Setup map of scenes & alert user if scene not configured properly
    for scene in scenes:
        if scene: # Don't error if there is an unfilled index in the scene map
            var instance = scene.instantiate()
            var entity_node = instance.get_node_or_null("PPEntityNode")
            if not entity_node:
                push_error("Scene is in the entity list but lacks PPEntityNode component: " + str(scene.resource_path))
            else:
                var entity_type = entity_node.type
                print("Readying "+entity_type+ " scene")
                scenes_map[entity_type] = scene
            instance.queue_free()  # Cleanup after checking
    
    
    sdk_node = SDKScript.new()
    
    if server_to_client_node and server_to_client_node.has_method("server_to_client"):
        print("got server_to_client")
        sdk_node.SetEventCallback(server_to_client_node)
    else:
        print("Assigned node does not have 'server_to_client' method.")
    
    sdk_node.SetGameID(game_id)
    
    var player_connected_timer = Timer.new()
    add_child(player_connected_timer)
    player_connected_timer.wait_time = 1.0
    player_connected_timer.connect("timeout", _on_player_connected_timer_timeout)
    player_connected_timer.start()
    
    new_player_entity.connect(_on_new_player_entity)
    new_entity.connect(_on_new_entity)
    remove_entity.connect(_on_remove_entity)
    new_chunk.connect(_on_new_chunk)
    remove_chunk.connect(_on_remove_chunk)


func _on_player_connected_timer_timeout():
    var new_player_is_connected = sdk_node.GetIsConnected()
    if not player_is_connected and new_player_is_connected:
        emit_signal("player_connected")
    if player_is_connected and not new_player_is_connected:
        emit_signal("player_disconnected")
    player_is_connected = new_player_is_connected


func authenticate_player(username: String, password: String):
    var thread = Thread.new()
    print("Attempting to connect player ",username)
    
    connect("player_authentication_error", Callable(self, "_on_player_authentication_error"))
    connect("player_authenticated", Callable(self, "_on_player_authenticated"))
    thread.start(Callable(self, "authenticate_player_thread").bind(username, password))
    await thread.wait_to_finish()
    
func authenticate_player_thread(username: String, password: String):
    var err : String = sdk_node.Connect(username, password)
    
    if err:
        player_uuid = null
        
        # Debug: Print before emitting the signal
        var callable = Callable(self, "emit_signal")
        var bound_callable = callable.bind("player_authentication_error", err)
        bound_callable.call_deferred()
        return
    
    player_uuid = sdk_node.GetUUID()
    
    var callable = Callable(self, "emit_signal")
    var bound_callable = callable.bind("player_authenticated", player_uuid)
    bound_callable.call_deferred()
    
func _on_player_authentication_error(error_message):
    print("Player failed authentication")
    push_error("Failed to authenticate player. Check credentials.")

func _on_player_authenticated(player_uuid):
    print("Authenticated successful. UUID: ", player_uuid)

func message(msg):
    sdk_node.Message(msg)

func direct_message(uuid, msg):
    sdk_node.DirectMessage(uuid, msg)

func _process(delta):
    if Engine.is_editor_hint() or !sdk_node or !player_uuid:
        return
    sdk_node.Update()
    
    # ----- ENTITIES ------
    # iterate through entities, emit changes
    var entities = sdk_node.GetEntities() 
    
    if entities:
        var entity_ids = entities.keys()
        var to_remove_entity_ids = registered_entities.duplicate()
        
        for entity_id in entity_ids:
            to_remove_entity_ids.erase(entity_id)
            
            var entity_data = entities[entity_id]
            if registered_entities.find(entity_id) == -1:
                if entity_id == player_uuid:
                    emit_signal("new_player_entity", player_uuid, entity_data)
                else:
                    emit_signal("new_entity", entity_id, entity_data)   
        emit_signal("entity_state_changed", entity_ids, entities.values())
        
        # Remove missing entities (any remaining from registered entities but not in updated entity ids loop)
        for entity_id in to_remove_entity_ids:
            if entity_id != player_uuid:
                emit_signal("remove_entity", entity_id)
        registered_entities = entity_ids
    
    # ----- CHUNKS ------
    # Iterate through chunks, emit changes 
    var chunks = sdk_node.GetChunks() 
    var chunk_ids = chunks.keys()
    var to_remove_chunk_ids = registered_chunks.duplicate()
    
    for chunk_id in chunk_ids:
        to_remove_chunk_ids.erase(chunk_id)
        
        var chunk_data = chunks[chunk_id]
        if registered_chunks.find(chunk_id) == -1: 
            emit_signal("new_chunk", chunk_id, chunk_data)             
    emit_signal("chunk_state_changed", chunk_ids, chunks.values())
    
    # Remove missing chunks (any remaining from registered chunks but not in updated chunk ids loop)
    for chunk_id in to_remove_chunk_ids:
        emit_signal("remove_chunk", chunk_id)
    registered_chunks = chunk_ids

func _get_property_list() -> Array:
    return [
        {"name": "game_id", "type": TYPE_STRING, "usage": PROPERTY_USAGE_READ_ONLY | PROPERTY_USAGE_DEFAULT if logged_in else PROPERTY_USAGE_DEFAULT},
        {"name": "pp_button_add_csproj_reference", "type": TYPE_STRING, "usage": PROPERTY_USAGE_DEFAULT} if not csproj_reference_exists else {}
    ]

func _validate_fields():
    var regex = RegEx.new()
    regex.compile("^[0-9]+$")
    if not regex.search(game_id):
        return {
            "valid": false,
            "message": "Game ID should be a numeric value"
        }
    return {
        "valid": true,
        "message": ""
    }

func _on_button_pressed(text:String):
    var validation_result = _validate_fields()
    assert(validation_result.valid, validation_result.message)
    if text.to_lower() == "add csproj reference":
        _on_csproj_button_pressed()
        return
        
func _get_csharp_error_msg():
    return "C# solution not created. Trigger Project > Tools > C# > Create C# Solution"

func _on_csproj_button_pressed():
    var csproj_files = Utils.find_files_by_extension(".csproj")
    assert(len(csproj_files), _get_csharp_error_msg())
    Utils.add_planetary_csproj_ref('res://' + csproj_files[0])
    notify_property_list_changed()

func _get_entity_nodes():
    var entity_nodes : Array = []
    var root = get_tree().get_edited_scene_root()

    _recursive_scene_entity_traversal(root, entity_nodes)
    return entity_nodes

func _recursive_scene_entity_traversal(node, entity_nodes):
    for child in node.get_children():
        if 'is_entity_node' in child and child.is_entity_node:
            entity_nodes.append(child)
            break
        _recursive_scene_entity_traversal(child, entity_nodes)

func _remove_all_entity_scenes():
    var root = get_tree().get_root()
    _recursive_scene_entity_removal(root)

func _recursive_scene_entity_removal(node):
    for child in node.get_children():
        if 'is_entity_node' in child and child.is_entity_node:
            node.queue_free()
            break
        _recursive_scene_entity_removal(child)
        
func _enter_tree():
    if not Engine.is_editor_hint():
        _remove_all_entity_scenes()
        return

    # check for existence of cs proj / sln files
    var csproj_files = Utils.find_files_by_extension(".csproj")
    csproj_reference_exists = false
    notify_property_list_changed()
    assert(len(csproj_files), _get_csharp_error_msg())
    assert(len(Utils.find_files_by_extension(".sln")), _get_csharp_error_msg())
    csproj_reference_exists = Utils.csproj_planetary_reference_exists(csproj_files[0])
    notify_property_list_changed()
    assert(csproj_reference_exists, "Planetary Processing reference does not exist in " + csproj_files[0] + "\nClick \"Add Csproj Reference\" in the PPRootNode inspector to add the reference.")


# create a new player instance, and add it as a child node
func _on_new_player_entity(entity_id, state):
    # create the player instance
    var player_instance = player_scene.instantiate()

    # validate that the player scene has a PPEntityNode
    var pp_entity_node = player_instance.get_node_or_null("PPEntityNode")
    if pp_entity_node:
        pp_entity_node.entity_id = entity_id
        print("making new player entity")
    else:
        print("PPEntityNode not found in the player instance")

    # add the player as a child of the root node
    add_child(player_instance)
    # position the player based on its server location
    # NOTE: Planetary Processing uses 'y' for depth in 3D games, and 'z' for height. The depth axis is also inverted.
    # To convert, set Godot's 'y' to negative, then swap 'y' and 'z'.
    player_instance.global_transform.origin = Vector3(state.x, state.z, -state.y)
    
#create an entity instance matching its type, and add it as a child node
func _on_new_entity(entity_id, state):
    # get the entity scene based on entity type
    var entity_scene = scenes_map.get(state.type)
    # validate that the entity type has a matching scene
    if not entity_scene:
        print("matching scene not found: " + state.type)

    # create an entity instance
    var entity_instance = entity_scene.instantiate()

    # validate that the entity scene has a PPEntityNode
    var pp_entity_node = entity_instance.get_node_or_null("PPEntityNode")
    if pp_entity_node:
        pp_entity_node.entity_id = entity_id
    else:
        print("PPEntityNode not found in the instance")

    add_child(entity_instance)
    entity_instance.global_transform.origin = Vector3(state.x, state.z, -state.y)
    

func _on_remove_entity(entity_id):
    for child in get_children():
        # check if the child is an entity 
        var pp_entity_node = child.get_node_or_null("PPEntityNode")

        # check if it matches the entity_id to be removed
        if pp_entity_node and pp_entity_node.entity_id == entity_id:
            # delink the child from the parent
            remove_child(child)
            # remove the child from processing
            child.queue_free()
            print('Entity ' + entity_id + ' removed')
            return
      
    print('Entity ' + entity_id + ' not found to remove')
    
    
#create an chunk instance matching its type, and add it as a child node
func _on_new_chunk(chunk_id, state):
    if not chunk_scene:
        print("No chunk scene provided. Chunk scene instantiation aborted" )
    else: 
        # create an chunk instance
        var chunk_instance = chunk_scene.instantiate()

        # validate that the entity scene has a PPEntityNode
        var pp_chunk_node = chunk_instance.get_node_or_null("PPChunkNode")
        if pp_chunk_node:
            pp_chunk_node.chunk_id = chunk_id
        else:
            print("PPChunkNode not found in the instance")

        # add the chunk as a child of the root node  
        add_child(chunk_instance)
        # position the entity based on its server location
        # NOTE: Planetary Processing uses 'y' for depth in 3D games, and 'z' for height. The depth axis is also inverted.
        # To convert, set Godot's 'y' to negative, then swap 'y' and 'z'.
        chunk_instance.global_transform.origin = Vector3((state.x * Chunk_Size), 0, -(state.y *  Chunk_Size))
    
# remove an chunk instance, from the current child nodes
func _on_remove_chunk(chunk_id):
    for child in get_children():
        # check if the child is a chunk
        var pp_chunk_node = child.get_node_or_null("PPChunkNode")

        # check if it matches the chunk_id to be removed
        if pp_chunk_node and pp_chunk_node.chunk_id == chunk_id:
            # delink the child from the parent
            remove_child(child)
            # remove the child from processing
            child.queue_free()
            print('Chunk ' + chunk_id + ' removed')
            return
      
    print('Chunk ' + chunk_id + ' not found to remove')
    
