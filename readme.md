# Introduction

Planetary processing provides a plugin for the Godot Engine. The plugin allows you to define your entities and their server side code within the Godot editor. Additionally, the plugin provides signals to connect to in your game client code - these communicate changes in state from your server side simulation to the game client itself.

## Pre-requisites

- Godot Engine v4.2.1+ **.net version required**
- .NET SDK 6.0+ (Desktop target)
- .NET SDK 7.0+ (Android target)
- .NET SDK 8.0+ (iOS target)

## Installation

- Clone the Planetary Processing Godot plugin from GitHub.

```sh
git clone https://github.com/planetary-processing/godot-plugin
```
- Create the _addons_ directory in your project if it does not exist
- Place the extracted _planetary_processing_ directory in the _addons_ directory
- Enable the Planetary Processing plugin via the Godot project settings

![Plugin Menu](https://planetaryprocessing.io/static/img/godot_plugin_menu.png)

- If not already setup on your project, you must trigger the creation of the C# solution via the Godot toolbar menu. This creates a _.csproj_ and a _.sln_ file in the root of your project.

![Csharp Menu](https://planetaryprocessing.io/static/img/godot_csharp1.png)

- Finally, we need to add a reference to the Planetary Processing C# SDK DLL to our _.csproj_ file. This can either be done manually, or via the button in the [PPRootNode](/docs/godot#introduction/custom-nodes/pprootnode) inspector. To add manually, please ensure the following reference is added to your ItemGroup in your _.csproj_ file

```xml
<Reference Include="Planetary">
  <HintPath>addons/planetary_processing/sdk/csharp-sdk.dll</HintPath>
</Reference>
```

## Custom Nodes

_Before reading this documentation, we recommend you are familiar with the [Conceptual Documentation](/docs#conceptual-documentation) for Planetary Processing_.

Once the Planetary Processing plugin is enabled, two custom nodes are made available to your project:

### PPRootNode

The Planetary Processing Root Node (PPRootNode) handles connections to your game backend, both when running your game and also when developing your game and making changes to your server side lua code.

A PPRootNode should be attached as a direct child of your scene's root node. It is intended to be attached to your main scene so as to be available across all child scene instances, although this may vary dependent on your project structure. Due to the way the node handles connections to your game simulation, you should only have one PPRootNode in your project.
![PPRootNode Scene Menu](https://planetaryprocessing.io/static/img/godot_root_scene_menu.png)

With the PPRootNode selected, you will be presented with the following in your inspector:
![PPRootNode Inspector Menu 1](https://planetaryprocessing.io/static/img/godot_root_inspector_1.png)
If you have already added the "Planetary" reference to your _csproj_ file, then the **Add Csproj Reference** button will not be visible. If it is present, you can click the button to have the plugin automatically add the reference to your _.csproj_ file.

Upon entering your Game ID (available in the [Planetary Processing Panel](https://panel.planetaryprocessing.io/)), Username and Password and clicking the Login button, you will see the inspector menu change state to one of the following:

If your game project is up to date with the latest version of the server side lua code for your game:
![PPRootNode Inspect Menu 2a](https://planetaryprocessing.io/static/img/godot_root_inspector_2a.png)

If there are changes to the server side lua code which can be fetched to your project:
![PPRootNode Inspect Menu 2b](https://planetaryprocessing.io/static/img/godot_root_inspector_2b.png)

#### Fetch

As shown above, the Fetch button will only be available when there have been changes to the server side lua code which are not yet reflected in your local copy of the game project. Clicking the button will fetch the latest server side lua code and write the files into _addons/planetary_processing/lua_ within your project directory. These files will be visible in the FileSystem explorer in the Godot editor:
![PPRootNode FileSystem](https://planetaryprocessing.io/static/img/godot_root_filesystem.png)
**Important Note this function will overwrite any changes you have made to your local lua that have not yet been published** Due to the code being in a git repository, you may restore old versions using the git CLI if necessary.

#### Publish

The publish button will traverse the scene looking for entity nodes (see [PPEntityNode](/docs/godot#introduction/custom-nodes/ppentitynode)), writing their properties into an _init.json_ file alongside the code in your _lua_ directory. Your lua and this json file are then pushed to your game repository as a new commit.

This means that you are able to create instances of scenes containing entity nodes within your main scene tree in the Godot editor. Once published to Planetary Processing, their properties such as their X, Y and Z position will be available to your _init.lua_ script via the _init.json_ file. Your init lua script can instantiate these entities in your game simulation, so as to replicate how you had configured your scenes in the godot editor. You can of course still instatiate entities in your simulation however you see fit, based on the [Server Side API Documentation](/docs#server-side-api-documentation).

#### Variables

The root node exposes the following useful variables

| name        | type           | description                                                                                                                 |
| ----------- | -------------- | --------------------------------------------------------------------------------------------------------------------------- |
| player_uuid | string or null | Will be null when the player is not authenticated. Once a player authenticates, this will be set to their unique identifier |

#### Methods

The root node exposes functions you can use to communicate with the server side game simulation.
|method|parameters|return value|description|
|--|--|--|--|
|authenticate_player|username: string, password: string|boolean: true if authenticated, will throw assertion error with error message if not|Authenticates a player with Planetary Processing.
|message|msg: Dictionary(String, Variant)|null|sends a message to the player entity on the server, which can then be processed by your player lua code|

#### Signals

The root node emits signals which you can use to manage the lifecycle of entities.
|name|parameters|description|
|--|--|--|
|new_player_entity|id: string, data: dictionary|fired when the player entity representing the player using this game client is spawned in the server side game simulation|
|new_entity|id: string, data: dictionary|fired when a new entity is spawned in the server side game simulation|
|remove_entity|id: string|fired when an entity is removed from the server side game simulation|

### PPEntityNode

The Planetary Processing Entity Node (PPEntityNode) describes a [Planetary Processing Entity](https://panel.planetaryprocessing.io/docs#server-side-api-documentation/types/entity). This node is designed to be attached directly to the root node of a scene in your Godot project, this scene can then be instantiated as a child of your main scene. For example, a tree scene will correlate with a _tree_ entity in Planetary Processing, and can have instances placed within your main scene.

With the PPEntityNode selected, you will be presented with the following in your inspector:
![PPEntityNode Inspector Menu 1](https://planetaryprocessing.io/static/img/godot_entity_inspector_1.png)

The type, data and chunkloader fields correlate with the fields as defined on the [server side Entity type](https://panel.planetaryprocessing.io/docs#server-side-api-documentation/types/entity).

| name        | description                                                                                                                      |
| ----------- | -------------------------------------------------------------------------------------------------------------------------------- |
| Data        | A JSON object, representing the data table you want to store about the entity type                                               |
| Chunkloader | This entity type will keep chunks it is present in from unloading, and will load any chunks it enters                            |
| Type        | The Entity Type. The value for this field is initially set based on the name of the root node of the scene it is placed in       |
| Lua Path    | The path to the lua file for this entity type. This can not be edited, it is based on the value you provide for your Type field. |

The below is an example of the inspector with representative values filled in:
![PPEntityNode Inspector Menu 2](https://planetaryprocessing.io/static/img/godot_entity_inspector_2.png)

#### Generate Lua Skeleton File

Clicking this button will create a placeholder lua file for your entity type if it does not exist already. The file name will be based on the Type field, with an output of the format _res://addons/planetary_processing/lua/entity/${type}.lua_.

## Usage

The Planetary Processing Plugin has an intended pattern of usage:

![Planetary Processing Usage Diagram](https://planetaryprocessing.io/static/img/godot_plugin_usage_diagram.png)

You may log a player in using the **authenticate_player** method on the **PPRootNode**. After logging a player in, the custom nodes will begin emitting signals.

For the player who has just logged in, the **PPRootNode** will emit a **new_player_entity** signal. This signal is specific to the player running this instance of the game client. You can hook into this signal and instantiate your player scene accordingly. An example handler for this signal would be:

      func _on_new_player_entity(entity_id, state):
        var player_instance = player_scene.instantiate()

        var ppEntityNode = player_instance.get_node("PPEntityNode")
        if not ppEntityNode:
          print("PPEntityNode not found in the player instance")
          return

        # godot engine Z is depth, Y is height, Planetary Processing Y is depth, Z is height
        player_instance.global_transform.origin = Vector3(state.x, state.z, state.y)
        ppEntityNode.entity_id = entity_id
        add_child(player_instance)

**Note in the above that a PPEntityNode requires its entity_id to be set after instantiation, so that the node knows which signals to filter out and re-emit.**

The **PPRootNode** will emit a **new_entity** signal for any entities that have not yet been seen by the game client. As an example, after logging in the PPRootNode will emit a new_entity signal for other players in the game world, at which point you can instantiate your player scene representing other players.

      var other_player_scene = preload("res://data/player/other_player.tscn")
      var tree_scene = preload("res://data/environment/tree_scene.tscn")

      var scene_map = {
        "player": other_player_scene,
        "tree": tree_scene
      }

      func _on_new_entity(entity_id, state):
        var entity_scene = scene_map.get(state.type)
        if not entity_scene:
          print("matching scene not found: " + state.type)

        var entity_instance = entity_scene.instantiate()
        var ppEntityNode = entity_instance.get_node("PPEntityNode")
        if not ppEntityNode:
          print("PPEntityNode not found in the instance")
          return

        entity_instance.global_transform.origin = Vector3(state.x, state.z, state.y)
        ppEntityNode.entity_id = entity_id
        add_child(entity_instance)

If any entities have left the simulation, the **PPRootNode** will emit a **remove_entity** signal. This signal can be used as a trigger to remove any scenes that are no longer needed from your tree. An example handler for this signal would be:

      func _on_remove_entity(entity_id):
        for child in get_children():
          var ppEntityNode = child.get_node("PPEntityNode")
          if ppEntityNode and ppEntityNode.entity_id == entity_id:
            remove_child(child)
            child.queue_free()
            return

Each **PPEntityNode** will emit a **state_changed** signal each frame, provided they are still part of the simulation. You can use these signals to trigger changes to your scenes as necessary, for example, moving player characters around the world. A simple example of how this might be handled in a script attached to the scene representing other players:

      extends CharacterBody3D

      func _ready():
        var ppEntityNode = get_node("PPEntityNode")
        ppEntityNode.state_changed.connect(_on_state_changed)

      func _on_state_changed(state):
        global_transform.origin = Vector3(state.x, state.z, state.y)

You can send regular updates from the player to the simulation using the **message** function on the **PPRootNode**. These messages allow the player to interact with the simulation. It is up to you what data you want to send and how to process it in your server side lua code. Depending on your game, you might choose to send updates every frame, or on a fixed time delta, for example every 33ms.

An example sending the updated player position every frame

      var pp_root_node
      var previous_position = Vector3.ZERO

      func _ready() -> void:
        ...
        pp_root_node = get_tree().current_scene.get_node('PPRootNode')
        assert(pp_root_node, "PPRootNode not found")

      func _process(delta):
        var current_position = transform.origin
        pp_root_node.message({
          "x": position_change[0],
          "y": position_change[1],
          "z": position_change[2]
        })

Your corresponding **player.lua** file may look like the following

      local function init(p)
      end

      local function update(p, dt)
      end

      local function message(e, msg)
        local x, y, z = msg.Data.x, msg.Data.y, msg.Data.z
        if msg.Client then e:MoveTo(x,z,y) end
      end

      return {init=init,update=update,message=message}

**It is important to note that the coordinate systems for 3 dimensional Godot games uses Y for height and Z for depth. Planetary Processing uses Y for depth in 3 dimensional games, and Z for height. As a result, coordinate values for 3 dimensional games need translating as seen in the above examples.**
