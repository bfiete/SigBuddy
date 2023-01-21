using System;
namespace SigBuddy;

static struct Utils
{
	public static char8[?] sBinaryChars = .('0', '1', 'x', 'z');
	public static char8[?] sHexChars = .(
		'0', '1', 'X', 'Z', '2', '3', 'X', 'Z', 'X', 'X', 'X', 'X', 'Z', 'Z', 'X', 'Z', '4', '5', 'X', 'Z', '6', '7', 'X', 'Z', 'X', 'X', 'X', 'X', 'Z', 'Z', 'X', 'Z', 
		'X', 'X', 'X', 'X', 'X', 'X', 'X', 'X', 'X', 'X', 'X', 'X', 'X', 'X', 'X', 'X', 'Z', 'Z', 'X', 'Z', 'Z', 'Z', 'X', 'Z', 'X', 'X', 'X', 'X', 'Z', 'Z', 'X', 'Z', 
		'8', '9', 'X', 'Z', 'A', 'B', 'X', 'Z', 'X', 'X', 'X', 'X', 'Z', 'Z', 'X', 'Z', 'C', 'D', 'X', 'Z', 'E', 'F', 'X', 'Z', 'X', 'X', 'X', 'X', 'Z', 'Z', 'X', 'Z', 
		'X', 'X', 'X', 'X', 'X', 'X', 'X', 'X', 'X', 'X', 'X', 'X', 'X', 'X', 'X', 'X', 'Z', 'Z', 'X', 'Z', 'Z', 'Z', 'X', 'Z', 'X', 'X', 'X', 'X', 'Z', 'Z', 'X', 'Z', 
		'X', 'X', 'X', 'X', 'X', 'X', 'X', 'X', 'X', 'X', 'X', 'X', 'X', 'X', 'X', 'X', 'X', 'X', 'X', 'X', 'X', 'X', 'X', 'X', 'X', 'X', 'X', 'X', 'X', 'X', 'X', 'X', 
		'X', 'X', 'X', 'X', 'X', 'X', 'X', 'X', 'X', 'X', 'x', 'X', 'X', 'X', 'X', 'X', 'X', 'X', 'X', 'X', 'X', 'X', 'X', 'X', 'X', 'X', 'X', 'X', 'X', 'X', 'X', 'X', 
		'Z', 'Z', 'X', 'Z', 'Z', 'Z', 'X', 'Z', 'X', 'X', 'X', 'X', 'Z', 'Z', 'X', 'Z', 'Z', 'Z', 'X', 'Z', 'Z', 'Z', 'X', 'Z', 'X', 'X', 'X', 'X', 'Z', 'Z', 'X', 'Z', 
		'X', 'X', 'X', 'X', 'X', 'X', 'X', 'X', 'X', 'X', 'X', 'X', 'X', 'X', 'X', 'X', 'Z', 'Z', 'X', 'Z', 'Z', 'Z', 'X', 'Z', 'X', 'X', 'X', 'X', 'Z', 'Z', 'X', 'z');
	public static char8[?] sOctalChars = .(
		'0', '1', 'X', 'Z', '2', '3', 'X', 'Z', 'X', 'X', 'X', 'X', 'Z', 'Z', 'X', 'Z', '4', '5', 'X', 'Z', '6', '7', 'X', 'Z', 'X', 'X', 'X', 'X', 'Z', 'Z', 'X', 'Z', 
		'X', 'X', 'X', 'X', 'X', 'X', 'X', 'X', 'X', 'X', 'x', 'X', 'X', 'X', 'X', 'X', 'Z', 'Z', 'X', 'Z', 'Z', 'Z', 'X', 'Z', 'X', 'X', 'X', 'X', 'Z', 'Z', 'X', 'z');

	public static void TimeToStr(double timeVal, String outStr)
	{
		if ((timeVal > 1) || (timeVal == 0))
		{
			outStr.AppendF($"{timeVal:0.###}s");
		}
		else if (timeVal >= 0.999e-3)
		{
			outStr.AppendF($"{timeVal/1e-3:0.###}ms");
		}
		else if (timeVal >= 0.999e-6)
		{
			outStr.AppendF($"{timeVal/1e-6:0.###}us");
		}
		else if (timeVal >= 0.999e-9)
		{
			outStr.AppendF($"{timeVal/1e-9:0.###}ns");
		}
		else if (timeVal >= 0.999e-12)
		{
			outStr.AppendF($"{timeVal/1e-12:0.###}ps");
		}
		else
		{
			outStr.AppendF($"{timeVal/1e-15:0.###}fs");
		}
	}
}