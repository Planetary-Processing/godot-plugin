using Godot;
using System;
using System.Collections.Generic;
using Planetary;

public partial class SDKNode : Node
{	
	private SDK sdk;
	
	public void Login(ulong gameId, string username, string password)
	{
		sdk = new SDK(
			gameId,
			username,
			password,
			s => GD.Print(s)
		);
		GD.Print("sdk instantiated for game ID " + gameId);
	}

	public override void _Process(double delta)
	{
		GD.Print("update");
		sdk.Update();
	}
}
