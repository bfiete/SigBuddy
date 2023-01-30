#pragma warning disable 168
using Beefy.theme.dark;
using Beefy.events;
using Beefy.widgets;
using System;

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
	public DarkEditWidget mEditWidget;
	public bool mFilterChanged;
	public SignalGroup mSignalGroup;

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

		mEditWidget = new DarkEditWidget();
		mEditWidget.mOnKeyDown.Add(new => EditKeyDownHandler);
		mEditWidget.mOnContentChanged.Add(new (evt) => { mFilterChanged = true; });
		AddWidget(mEditWidget);
	}

	void EditKeyDownHandler(KeyDownEvent evt)
	{
		if ((evt.mKeyCode == .Down) || (evt.mKeyCode == .Up))
		{
			var root = mListView.GetRoot();
			var focusedItem = root.FindFocusedItem();
			if ((focusedItem == null) && (root.GetChildCount() > 0))
			{
				if (evt.mKeyCode == .Down)
					root.GetChildAtIndex(0).Focused = true;
				else
					root.GetChildAtIndex(root.GetChildCount() - 1).Focused = true;
				return;
			}
		}

		switch (evt.mKeyCode)
		{
		case .Up,
			 .Down,
			 .PageUp,
			 .PageDown:
			mListView.KeyDown(evt.mKeyCode, false);
		case .Return:
			DoAddEntry();
		default:
		}

		if (evt.mKeyFlags == .Ctrl)
		{
			switch (evt.mKeyCode)
			{
			case .Home,
				 .End:
				mListView.KeyDown(evt.mKeyCode, false);
			default:
			}
		}
	}

	void DoAddEntry()
	{
		var sigPanel = gApp.mSigPanel;
		var entry = sigPanel.CreateEntry();

		mListView.GetRoot().WithSelectedItems(scope (lvi) =>
			{
				var sigListViewItem = lvi as SigListViewItem;
				entry.mSignal = sigListViewItem.mSignal;
			});
	}

	void ListViewItemMouseDown(ListViewItem item, float x, float y, int32 btnNum, int32 clickCount)
	{
		mListView.SetFocus();

		var sigListViewItem = item as SigListViewItem;

		if (sigListViewItem.mColumnIdx != 0)
		    sigListViewItem = sigListViewItem.GetSubItem(0) as SigListViewItem;

		mListView.GetRoot().SelectItemExclusively(sigListViewItem);

		if ((btnNum == 0) && (clickCount == 2))
		{
			DoAddEntry();
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
	    mListView.Resize(0, 0, mWidth, mHeight - GS!(20));
		mEditWidget.Resize(0, mHeight - GS!(20), mWidth, GS!(20));
	}

	public void RebuildData(SignalGroup sigGroup)
	{
		mSignalGroup = sigGroup;

		var rootListViewItem = mListView.GetRoot();

		String focusName = scope .();
		var focusedItem = rootListViewItem.FindFocusedItem();
		if (focusedItem != null)
			focusName.Set(focusedItem.GetSubItem(1).Label);

		rootListViewItem.Clear();

		if (sigGroup.mSortDirty)
		{
			sigGroup.mSignals.Sort(scope (lhs, rhs) => String.Compare(lhs.mName, rhs.mName, true));
			sigGroup.mSortDirty = false;
		}

		String filter = mEditWidget.GetText(.. scope .());
		filter.Trim();
		
		for (var item in sigGroup.mSignals)
		{
			if (!filter.IsEmpty)
			{
				if (!item.mName.Contains(filter, true))
					continue;
			}

			var listViewItem = rootListViewItem.CreateChildItem() as SigListViewItem;
			listViewItem.mSignal = item;
			if (item.mKind == .Reg)
				listViewItem.Label = "reg";
			else if (item.mKind == .Parameter)
				listViewItem.Label = "param";
			else
				listViewItem.Label = "wire";

			var subListViewItem = listViewItem.CreateSubItem(1);

			var label = scope String(64);
			label.Append(item.mName);
			if (item.mDims != null)
				label.Append(item.mDims);

			subListViewItem.Label = label;

			if ((!focusName.IsEmpty) && (label == focusName))
				rootListViewItem.SelectItemExclusively(listViewItem);
		}
	}

	public void Clear()
	{
		mListView.GetRoot().Clear();
		mSignalGroup = null;
	}

	public override void Update()
	{
		base.Update();

		if (mFilterChanged)
		{
			if (mSignalGroup != null)
				RebuildData(mSignalGroup);
			mFilterChanged = false;
		}
	}
}