using System;
using System.Collections;

namespace SigBuddy;

class Program
{
	public static int Main(String[] args)
	{
		SBApp app = new .();
		app.ParseCommandLine(args);
		app.Init();
		app.Run();
		app.Shutdown();
		delete app;

		return 0;
	}
}