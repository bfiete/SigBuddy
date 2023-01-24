using System;

namespace SigBuddy;

class WaveFormat
{
	public virtual Result<void> Load(StringView filePath)
	{
		return .Err;
	}

	public virtual Result<void> Save(StringView filePath)
	{
		return .Err;
	}
}
