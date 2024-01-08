using Godot;
using System;
using System.Collections.Generic;
using Planetary;

public partial class SDKNode : Node
{	
	private SDK sdk;
	private ulong gameId;
	
	public void SetGameID(ulong gameId)
	{
		this.gameId = gameId;
		sdk = new SDK(
			gameId
		);
		GD.Print("SDKNode game ID " + gameId);
	}
	
	public string Connect(string username, string password)
	{
		try 
		{
			sdk.Connect(username, password);
			GD.Print("Player " + username + " authenticated on game ID " + gameId);
			return "";
		}
		catch (Exception e)
		{
			return e.Message;
		}
	}
	
	public void Message(Godot.Collections.Dictionary<string, Godot.Variant> msg)
	{
		Dictionary<string, dynamic> message = new Dictionary<string, dynamic>();
		foreach (var key in msg.Keys)
		{
			dynamic value = msg[key];
			message[key] = value;
		}
		sdk.Message(message);
	}

	public void Update()
	{
		sdk.Update();
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
			gdEntity["data"] = entity.data;
			gdEntity["type"] = entity.type;

			gdEntities[entity.id] = gdEntity;
		}

		return gdEntities;
	}
}
