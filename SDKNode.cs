using Godot;
using System;
using System.Collections.Generic;
using System.Text.Json;
using Planetary;

public partial class SDKNode : Node
{	
	private SDK sdk;
	private ulong gameId;
	private Godot.Collections.Dictionary<string, Godot.Variant> chunkMap = new Godot.Collections.Dictionary<string, Godot.Variant>();

	public uint chunkSize;
	
	public void SetGameID(ulong gameId)
	{
		this.gameId = gameId;
		sdk = new SDK(
			gameId,
			this.HandleChunk
		);
		GD.Print("SDKNode game ID " + gameId);
	}
	
	public string Connect(string username, string password)
	{
		try 
		{
			sdk.Connect(username, password);
			GD.Print("Player " + username + " authenticated on game ID " + gameId);
			sdk.Join();
			return "";
		}
		catch (Exception e)
		{
			return e.Message;
		}
	}
	
	public bool GetIsConnected()
	{
		return sdk.IsConnected();
	}
	
	public string GetUUID()
	{
		return sdk.UUID;
	}
	
	public void Message(Godot.Collections.Dictionary<string, Godot.Variant> msg)
	{
		Dictionary<string, dynamic> message = new Dictionary<string, dynamic>();
		foreach (var key in msg.Keys)
		{
			dynamic value = msg[key];
			message[key] = ConvertFromGodotVariant(value);
		}
		sdk.Message(message);
	}
	
	private dynamic ConvertFromGodotVariant(Godot.Variant value)
	{
		switch (value.VariantType)
		{
			case Godot.Variant.Type.Nil:
				return null;
			case Godot.Variant.Type.Bool:
				return value.As<bool>();
			case Godot.Variant.Type.Int:
				return value.As<long>();
			case Godot.Variant.Type.Float:
				return value.As<double>();
			case Godot.Variant.Type.String:
				return value.As<string>();
			case Godot.Variant.Type.Dictionary:
				var godotDict = value.As<Godot.Collections.Dictionary<string, Godot.Variant>>();
				var csharpDict = new Dictionary<string, dynamic>();
				foreach (var dictKey in godotDict.Keys)
				{
					dynamic dictValue = ConvertFromGodotVariant(godotDict[dictKey]);
					csharpDict[dictKey] = dictValue;
				}
				return csharpDict;
			default:
				return null;
		}
	}

	private Godot.Variant ConvertToGodotVariant(dynamic value)
	{
		bool isDict = value.GetType().IsGenericType && value.GetType().GetGenericTypeDefinition() == typeof(Dictionary<,>);
		if (isDict) {
				var gdDict = new Godot.Collections.Dictionary<Godot.Variant, Godot.Variant>();
				foreach ((dynamic key, dynamic val) in (Dictionary<object, object>)value)
				{
					gdDict[key] = ConvertToGodotVariant(val);
				}
				return gdDict;
		}
		return value;
	}
	
	private Godot.Collections.Dictionary<string, Godot.Variant> ConvertToGodotVariantDictionary(Dictionary<string, dynamic> dict)
	{
		var gdDict = new Godot.Collections.Dictionary<string, Godot.Variant>();
		foreach (var kvp in dict)
		{
			gdDict[kvp.Key] = ConvertToGodotVariant(kvp.Value);
		}
		return gdDict;
	}

	public void Update()
	{
		sdk.Update();
		if (!sdk.entities.ContainsKey(sdk.UUID)) {
			sdk.Join();
		}
	}
	
	public Godot.Collections.Dictionary<string, Godot.Variant> GetEntities()
	{
		Godot.Collections.Dictionary<string, Godot.Variant> gdEntities = new Godot.Collections.Dictionary<string, Godot.Variant>();

		foreach (var pair in sdk.entities)
		{
			Entity entity = pair.Value;
			Godot.Collections.Dictionary<string, Godot.Variant> gdEntity = new Godot.Collections.Dictionary<string, Godot.Variant>();
			gdEntity["x"] = entity.x;
			gdEntity["y"] = entity.y;
			gdEntity["z"] = entity.z;
			gdEntity["data"] = ConvertToGodotVariantDictionary(entity.data);
			gdEntity["type"] = entity.type;

			gdEntities[entity.id] = gdEntity;
		}
		return gdEntities;
	}

	private void HandleChunk(Chunk cnk) {
		/*
		Function passed to SDK as part of init (or closest proxy to, SetGameId) 
		*/
		if (!chunkMap.ContainsKey(cnk.id.ToString())) {
		  // Create a new dictionary to represent the chunk
			Godot.Collections.Dictionary<string, Godot.Variant> gdChunk = new Godot.Collections.Dictionary<string, Godot.Variant>();

			// Set the gdChunk data
			gdChunk["data"] = ConvertToGodotVariantDictionary(cnk.data);
			gdChunk["x"] = cnk.x;
			gdChunk["y"] = cnk.y;
			gdChunk["id"] = cnk.id.ToString();

			// Add the new chunk to the map
			chunkMap[cnk.id.ToString()] = gdChunk;

			GD.Print($"Added new chunk with ID {cnk.id}, x=({cnk.x}, y={cnk.y})");
		} else {
			// The chunk already exists, update its data if necessary
			Godot.Variant existingChunkVariant = chunkMap[cnk.id.ToString()];
			 if (existingChunkVariant.Obj is Godot.Collections.Dictionary existingChunk) {
				// Update chunk data if needed
				existingChunk["data"] = ConvertToGodotVariantDictionary(cnk.data);
				GD.Print($"Updated existing chunk with ID {cnk.id}");
			} else {
				GD.PrintErr($"Failed to update chunk with ID {cnk.id}: existing chunk is null or invalid.");
			}
		}
		// Remove chunks further than 3 from the player's current chunk
		// We don't have access to player coords easily here, so use other chunks:
		// 	updates will only be sent from chunks within 3, so remove those 3 away from cnk
		// pseudocode:
		// make empty list toRemove
		// foreach id, chunk in chunkMap {
		// if abs(chunk.x - cnk.x) > 3 or  abs(chunk.y - cnk.y) > 3} {
		// 	add chunk to toRemove
		// }}
		// foreach id in toRemove {
		// 	remove id from chunkMap}
		
		List<string> toRemove = new List<string>();
		foreach (string chunk_id in chunkMap.Keys) {
			// Get the chunk from the dictionary
			if (!chunkMap.TryGetValue(chunk_id, out Godot.Variant savedChunkVariant)) {
				GD.PrintErr($"Chunk ID {chunk_id} not found in chunkMap");
				continue;
			}
			var savedChunk = savedChunkVariant.As<Godot.Collections.Dictionary<string, Godot.Variant>>();
			if (savedChunk != null) {
				if (Math.Abs((int)savedChunk["x"] - cnk.x) > 3 || Math.Abs((int)(savedChunk["y"]) - cnk.y) > 3) {
					toRemove.Add(chunk_id);
				}
			} else {
				GD.PrintErr($"Error - Failed to extract dictionary for chunk {chunk_id}.");
			}
		}

		// Remove the chunks marked for removal
		foreach (string chunkId in toRemove) {
			chunkMap.Remove(chunkId);
		}
	}
	
	public Godot.Collections.Dictionary<string, Godot.Variant> GetChunks()
	{

		return chunkMap;
	}
	
}
