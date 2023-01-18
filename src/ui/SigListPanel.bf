using Beefy.theme.dark;
using Beefy.events;
using Beefy.widgets;

namespace SigBuddy.ui;

class SigListView : DarkListView
{
	protected override ListViewItem CreateListViewItem()
	{
		return new SigListViewItem();
	}
}

class SigListViewItem : DarkListViewItem
{
	public Signal mSignal;

}

class SigListPanel : Panel
{
	public SigListView mListView;

	public this()
	{
		mListView = new .();
		//mListView.mProjectPanel = this;
		//mListView.mOnEditDone.Add(new => HandleEditDone);

		mListView.SetShowHeader(true);
		mListView.InitScrollbars(false, true);
		//mListView.mHorzScrollbar.mPageSize = GS!(100);
		//mListView.mHorzScrollbar.mContentSize = GS!(500);
		mListView.mVertScrollbar.mPageSize = GS!(100);
		mListView.mVertScrollbar.mContentSize = GS!(500);
		mListView.mLabelX = GS!(6);
		//mListView.mIconX = GS!(20);
		//mListView.mChildIndent = GS!(12);
		mListView.UpdateScrollbars();
		//mListView.mOnFocusChanged.Add(new => FocusChangedHandler);

		//mListView.mOnDragEnd.Add(new => HandleDragEnd);
		//mListView.mOnDragUpdate.Add(new => HandleDragUpdate);

		AddWidget(mListView);

		mListView.mOnMouseClick.Add(new => ListViewClicked);
		mListView.mOnMouseDown.Add(new => ListViewMouseDown);
		mListView.mOnItemMouseDown.Add(new => ListViewItemMouseDown);
		mListView.mOnItemMouseClicked.Add(new => ListViewItemClicked);

		mListView.AddColumn(GS!(50), "Kind");
		mListView.AddColumn(GS!(100), "Name");
	}

	void ListViewItemMouseDown(ListViewItem item, float x, float y, int32 btnNum, int32 clickCount)
	{
		var sigListViewItem = item as SigListViewItem;

		if (sigListViewItem.mColumnIdx != 0)
		    sigListViewItem = sigListViewItem.GetSubItem(0) as SigListViewItem;

		mListView.GetRoot().SelectItemExclusively(sigListViewItem);

		if ((btnNum == 0) && (clickCount == 2))
		{
			var entry = new SigPanel.Entry();
			entry.mSignal = sigListViewItem.mSignal;
			gApp.mSigPanel.mEntries.Add(entry);
			gApp.mSigPanel.mSigActiveListPanel.RebuildData();
		}

		if (btnNum == 1)
		{
			/*Widget widget = (DarkListViewItem)theEvent.mSender;
			float clickX = theEvent.mX;
			float clickY = widget.mHeight + GS!(2);
		    float aX, aY;
		    widget.SelfToOtherTranslate(mListView.GetRoot(), clickX, clickY, out aX, out aY);*/
		    //ShowRightClickMenu(mListView, aX, aY);
		}
		else
		{                
		    //if (anItem.IsParent)
		        //anItem.Selected = false;
		}
	}

	void ListViewItemClicked(ListViewItem item, float x, float y, int32 btnNum)
	{
		var item;
		if (item.mColumnIdx != 0)
		    item = item.GetSubItem(0);

		//mListView.GetRoot().SelectItemExclusively(item);

		if (btnNum == 1)
		{
			/*Widget widget = (DarkListViewItem)theEvent.mSender;
			float clickX = theEvent.mX;
			float clickY = widget.mHeight + GS!(2);
		    float aX, aY;
		    widget.SelfToOtherTranslate(mListView.GetRoot(), clickX, clickY, out aX, out aY);*/
		    //ShowRightClickMenu(mListView, aX, aY);
		}
		else
		{                
		    //if (anItem.IsParent)
		        //anItem.Selected = false;
		}
	}

	void ListViewClicked(MouseEvent theEvent)
	{
		if (theEvent.mBtn == 1)
		{
		    float aX, aY;
		    theEvent.GetRootCoords(out aX, out aY);
		    //ShowRightClickMenu(mListView, aX, aY);
		}
	}

	void ListViewMouseDown(MouseEvent theEvent)
	{
	    // We clicked off all items, so deselect
		//mListView.GetRoot().WithSelectedItems(scope (item) => { item.Selected = false; } );
	}

	public override void Resize(float x, float y, float width, float height)
	{
	    base.Resize(x, y, width, height);
	    mListView.Resize(0, 0, mWidth, mHeight);
	}

	public void RebuildData(SignalGroup sigGroup)
	{
		var rootListViewItem = mListView.GetRoot();
		rootListViewItem.Clear();

		for (var item in sigGroup.mSignals)
		{
			var listViewItem = rootListViewItem.CreateChildItem() as SigListViewItem;
			listViewItem.mSignal = item;
			if (item.mKind == .Reg)
				listViewItem.Label = "reg";
			else if (item.mKind == .Parameter)
				listViewItem.Label = "param";
			else
				listViewItem.Label = "wire";

			var subListViewItem = listViewItem.CreateSubItem(1);
			subListViewItem.Label = item.mName;
		}
	}
}