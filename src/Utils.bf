using System;
namespace SigBuddy;

static struct SigUtils
{
	[Reflect]
	public enum DataFormat
	{
		Auto,
		Binary,
		Hex,
		Decimal,
		DecimalSigned,
		Octal,
		Ascii,
	}

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

	public static void TimeToStr(double timeVal, String outStr, int32 timeResDigits)
	{
		String suffix = "";
		double scaledVal = 0;

		if ((timeVal > 1) || (timeVal == 0))
		{
			suffix = "s";
			scaledVal = timeVal;
			
		}
		else if (timeVal >= 0.999e-3)
		{
			suffix = "ms";
			scaledVal = timeVal/1e-3;
		}
		else if (timeVal >= 0.999e-6)
		{
			suffix = "us";
			scaledVal = timeVal/1e-6;
		}
		else if (timeVal >= 0.999e-9)
		{
			suffix = "ns";
			scaledVal = timeVal/1e-9;
		}
		else if (timeVal >= 0.999e-12)
		{
			suffix = "ps";
			scaledVal = timeVal/1e-12;
		}
		else
		{
			suffix = "fs";
			scaledVal = timeVal/1e-15;
		}

		if (timeResDigits <= 4)
			outStr.AppendF($"{scaledVal:0.###}{suffix}");
		else if (timeResDigits <= 5)
			outStr.AppendF($"{scaledVal:0.####}{suffix}");
		else if (timeResDigits <= 6)
			outStr.AppendF($"{scaledVal:0.#####}{suffix}");
		else if (timeResDigits == 7)
			outStr.AppendF($"{scaledVal:0.######}{suffix}");
		else if (timeResDigits == 8)
			outStr.AppendF($"{scaledVal:0.#######}{suffix}");
		else if (timeResDigits == 9)
			outStr.AppendF($"{scaledVal:0.########}{suffix}");
		else
			outStr.AppendF($"{scaledVal:0.#########}{suffix}");
	}

	public static Result<double> StringToTime(StringView str)
	{
		Result<double> HandleTime(double scale, int suffixLen = 2)
		{
			double val = Try!(double.Parse(str.Substring(0, str.Length - suffixLen)..Trim()));
			return val *= scale;
		}

		if (str.EndsWith("ms"))
			return HandleTime(1e-3);
		if (str.EndsWith("us"))
			return HandleTime(1e-6);
		if (str.EndsWith("ns"))
			return HandleTime(1e-9);
		if (str.EndsWith("ps"))
			return HandleTime(1e-12);
		if (str.EndsWith("fs"))
			return HandleTime(1e-15);
		if (str.EndsWith("s"))
			return HandleTime(1, 1);
		return .Err;
	}

	public static Result<uint64> ParseValue(StringView str, DataFormat? defaultFormat = null)
	{
		DataFormat? useFormat = defaultFormat;

		StringView valueStr = str;
		valueStr.Trim();

		if (valueStr.StartsWith("'d"))
		{
			useFormat = .Decimal;
			valueStr.RemoveFromStart(2);
		}
		else if (valueStr.StartsWith("'h"))
		{
			useFormat = .Hex;
			valueStr.RemoveFromStart(2);
		}
		else if (valueStr.StartsWith("'b"))
		{
			useFormat = .Binary;
			valueStr.RemoveFromStart(2);
		}
		else if (valueStr.StartsWith("'o"))
		{
			useFormat = .Octal;
			valueStr.RemoveFromStart(2);
		}

		if (useFormat == null)
			useFormat = .Decimal;

		uint64 radix = 0;
		switch (useFormat.Value)
		{
		case .Ascii:
			radix = 256;
		case .Binary:
			radix = 2;
		case .Decimal:
			radix = 10;
		case .Hex:
			radix = 16;
		case .Octal:
			radix = 8;
		default:
		}

		uint64 value = 0;
		for (var c in str)
		{
			uint64 cVal = 0;
			if ((c >= '0') && (c <= '9'))
				cVal = (.)(c - '0');
			else if ((c >= 'A') && (c <= 'F') && (radix == 16))
			{
				cVal = (.)(c - 'A') + 10;
			}
			else if ((c >= 'a') && (c <= 'f') && (radix == 16))
			{
				cVal = (.)(c - 'a') + 10;
			}
			else
				return .Err;

			if (cVal >= radix)
				return .Err;

			value *= radix;
			value += cVal;
		}

		return .Ok(value);
	}
}