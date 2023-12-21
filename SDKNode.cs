using Godot;
using System;
using System.Collections.Generic;
using Planetary;

public partial class SDKNode : Node
{	
	private SDK sdk;
	
	public void Login()
	{
		sdk = new SDK(
			56,
			"james.lovatt@planetaryprocessing.io",
			"aJSJHhjdfgjhjasdl4",
			s => GD.Print(s)
		);
		GD.Print(sdk);
	}

	public override void _Process(double delta)
	{
		GD.Print("update");
		sdk.Update();
	}
}
