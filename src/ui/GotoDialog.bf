using Beefy.theme.dark;
using Beefy.widgets;
using Beefy.gfx;
using System;

namespace SigBuddy.ui;

class GotoDialog : DarkDialog
{
	EditWidget mEditWidget;

	public this() : base("Go to Time")
	{
		mWindowFlags = .ClientSized | .TopMost | .Caption |
		    .Border | .SysMenu | .PopupPosition;

		AddOkCancelButtons(new (evt) => { DoFind(); }, null, 0, 1);

		mEditWidget = AddEdit("");
	}

	public override void CalcSize()
	{
	    mWidth = GS!(300);
	    mHeight = GS!(96);
	}

	public void DoFind()
	{

	}

	public override void Draw(Graphics g)
	{
	    base.Draw(g);

	    g.DrawString("Time:", GS!(16), mEditWidget.mY - GS!(18));
	}

	public override void Submit()
	{
		var timeStr = mEditWidget.GetText(.. scope .());

		switch (SigUtils.StringToTime(timeStr))
		{
		case .Ok(let val):
			gApp.mSigPanel.mSigViewPanel.mCursorTick = val / gApp.mSigData.mTimescale;
			gApp.mSigPanel.mSigViewPanel.EnsureCursorVisible();
			Close();
		case .Err:
			gApp.Fail("Invalid time value");
		}
	}
}