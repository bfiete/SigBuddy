using Beefy.theme.dark;
using Beefy.widgets;
using Beefy.gfx;
using System;

namespace SigBuddy.ui;

class FindDialog : DarkDialog
{
	EditWidget mEditWidget;

	public this() : base("Find Signal Value")
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

	    g.DrawString("Find value:", GS!(16), mEditWidget.mY - GS!(18));
	}

	public override void Submit()
	{
		SigPanel.Entry selectedEntry = null;
		bool hadMultipleEntries = false;

		gApp.mSigPanel.mSigActiveListPanel.mListView.GetRoot().WithSelectedItems(scope [&] (listViewItem) =>
			{
				var activeListViewItem = (SigActiveListViewItem)listViewItem;
				if (selectedEntry != null)
					hadMultipleEntries = true;
				selectedEntry = activeListViewItem.mEntry;

			});

		if (hadMultipleEntries)
		{
			gApp.Fail("Only one signal can be selected");
			return;
		}
		else if (selectedEntry == null)
		{
			gApp.Fail("No search target signal was selected");
			return;
		}
		else if (selectedEntry.mSignal.mNumBits > 64)
		{
			gApp.Fail("Cannot search in signals with more than 64 bits");
			return;
		}

		uint64 value = 0;

		String text = mEditWidget.GetText(.. scope .());
		switch (SigUtils.ParseValue(text))
		{
			case .Ok(out value):
			case .Err:
				gApp.Fail("Invalid value");
				return;
		}

		uint32[4] findValue = default;
		for (int bit = 0; bit < 64; bit++)
		{
			findValue[bit/16] |= (.)(((value >> bit) & 1) << ((bit * 2) % 32));
		}

		var sigViewPanel = gApp.mSigPanel.mSigViewPanel;
		sigViewPanel.mLastFindEntry = selectedEntry;
		DeleteAndNullify!(sigViewPanel.mLastFindData);
		sigViewPanel.mLastFindData = new System.Collections.List<uint32>();
		sigViewPanel.mLastFindData.AddRange(.(&findValue, 4));

		PassLoop: for (int pass < 2)
		{
			int64 startTick = (.)sigViewPanel.mCursorTick.GetValueOrDefault();
			if (pass == 1)
			{
				if (startTick == 0)
					break;
				startTick = 0;
			}

			switch (selectedEntry.FindValue(&findValue, startTick))
			{
			case .Ok(let val):
				gApp.mSigPanel.mSigViewPanel.CursorTick = val;
				gApp.mSigPanel.mSigViewPanel.EnsureCursorVisible();
				break PassLoop;
			case .Err(let err):
				gApp.Fail("Value not found");
			}
		}
		
		Close();
	}
}