using Beefy.theme.dark;
using Beefy.events;
using Beefy.widgets;
namespace SigBuddy.ui;

class SigGroupListView : DarkListView
{
	protected override ListViewItem CreateListViewItem()
	{
		return new SigGroupListViewItem();
	}
}

class SigGroupListViewItem : DarkListViewItem
{
	public SignalGroup mSignalGroup;

	public override bool Focused
	{
		set
		{
			if (value)
			{
				gApp.mSigListPanel.RebuildData(mSignalGroup);
			}
			base.Focused = value;
		}
	}
}

class SigGroupPanel : Panel
{
	public SigGroupListView mListView;

	public this()
	{
		mListView = new .();
		//mListView.mProjectPanel = this;
		//mListView.mOnEditDone.Add(new => HandleEditDone);

		mListView.SetShowHeader(false);
		mListView.InitScrollbars(false, true);
		/*mListView.mHorzScrollbar.mPageSize = GS!(100);
		mListView.mHorzScrollbar.mContentSize = GS!(500);*/
		mListView.mVertScrollbar.mPageSize = GS!(100);
		mListView.mVertScrollbar.mContentSize = GS!(500);
		mListView.mLabelX = GS!(42);
		mListView.mIconX = GS!(20);
		mListView.mChildIndent = GS!(12);
		mListView.UpdateScrollbars();
		//mListView.mOnFocusChanged.Add(new => FocusChangedHandler);

		//mListView.mOnDragEnd.Add(new => HandleDragEnd);
		//mListView.mOnDragUpdate.Add(new => HandleDragUpdate);

		AddWidget(mListView);

		mListView.mOnMouseClick.Add(new => ListViewClicked);
		mListView.mOnMouseDown.Add(new => ListViewMouseDown);
		mListView.mOnItemMouseDown.Add(new => ListViewItemMouseDown);
		mListView.mOnItemMouseClicked.Add(new => ListViewItemClicked);

		mListView.AddColumn(GS!(100), "Name");

	}

	void ListViewItemMouseDown(ListViewItem item, float x, float y, int32 btnNum, int32 clickCount)
	{
		var item;
		if (item.mColumnIdx != 0)
		    item = item.GetSubItem(0);

		mListView.GetRoot().SelectItemExclusively(item);

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

	public void RebuildData()
	{
		mListView.GetRoot().Clear();

		void HandleGroup(SigGroupListViewItem listViewItem, SignalGroup sigGroup)
		{
			var subListViewItem = listViewItem.CreateChildItem() as SigGroupListViewItem;
			subListViewItem.mSignalGroup = sigGroup;
			subListViewItem.Label = sigGroup.mName;
			subListViewItem.IconImage = DarkTheme.sDarkTheme.GetImage(.ProjectFolder);
			//subListViewItem.LabelX = GS!();

			if (sigGroup.mNestedGroups != null)
			{
				subListViewItem.MakeParent();
				subListViewItem.Open(true, true);
				for (var subGroup in sigGroup.mNestedGroups)
				{
					HandleGroup(subListViewItem, subGroup);
				}
			}

			if (listViewItem == mListView.GetRoot())
			{
				subListViewItem.Focused = true;
			}
		}

		var sigData = gApp.mSigData;

		if (sigData.mRoot.mNestedGroups != null)
		{
			var topItem = mListView.GetRoot() as SigGroupListViewItem;

			if (!sigData.mRoot.mSignals.IsEmpty)
			{
				topItem = mListView.GetRoot().CreateChildItem() as SigGroupListViewItem;
				topItem.mSignalGroup = sigData.mRoot;
				topItem.Label = "TOP";
				topItem.IconImage = DarkTheme.sDarkTheme.GetImage(.ProjectFolder);
				topItem.MakeParent();
				topItem.Open(true, true);
			}

			for (var subGroup in sigData.mRoot.mNestedGroups)
			{
				HandleGroup(topItem, subGroup);
			}
		}
	}

	public void Clear()
	{
		mListView.GetRoot().Clear();
	}
}