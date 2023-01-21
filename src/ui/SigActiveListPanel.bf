using Beefy.theme.dark;
using Beefy.events;
using Beefy.widgets;
using Beefy.gfx;
using Beefy.theme;
using System;
using System.Collections;

namespace SigBuddy.ui;

class SigActiveListView : DarkListView
{
	protected override ListViewItem CreateListViewItem()
	{
		return new SigActiveListViewItem();
	}
}

class SigActiveListViewItem : DarkListViewItem
{
	public SigPanel.Entry mEntry;

	public override void Init(ListView listView)
	{
		base.Init(listView);
		mSelfHeight = GS!(20);
	}

	public override void Resize(float x, float y, float width, float height)
	{
		base.Resize(x, y, width, height);

		if (mEntry != null)
		{
			SelfToOtherTranslate(mListView.mScrollContent, 0, 0, var transX, var transY);
			mEntry.mY = transY + GS!(20);
		}
	}
}

class SigActiveListPanel : Panel
{
	public SigPanel mSigPanel;
	public SigActiveListView mListView;

	public this()
	{
		mListView = new .();
		//mListView.mProjectPanel = this;
		//mListView.mOnEditDone.Add(new => HandleEditDone);

		mListView.SetShowHeader(true);
		mListView.InitScrollbars(false, false);
		//mListView.mHorzScrollbar.mPageSize = GS!(100);
		//mListView.mHorzScrollbar.mContentSize = GS!(500);
		//mListView.mVertScrollbar.mPageSize = GS!(100);
		//mListView.mVertScrollbar.mContentSize = GS!(500);
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

		mListView.mOnDragEnd.Add(new => HandleDragEnd);
		mListView.mOnDragUpdate.Add(new => HandleDragUpdate);

		mListView.AddColumn(GS!(100), "Name");
		mListView.AddColumn(GS!(100), "Value");
	}

	void ListViewItemMouseDown(ListViewItem item, float x, float y, int32 btnNum, int32 clickCount)
	{
		var item;
		if (item.mColumnIdx != 0)
		    item = item.GetSubItem(0);

		if (btnNum == 1)
		{
			if (item.Selected)
				return; // Leave alone
		}

		mListView.GetRoot().SelectItem(item, true);

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

	public MenuWidget ShowRightClickMenu(Widget relWidget, float x, float y, bool itemClicked)
	{
		Menu menu = new Menu();

		if (itemClicked)
		{
			var subMenu = menu.AddItem("Data Format");

			HashSet<SigPanel.DataFormat> usedFormats = scope .();
			mListView.GetRoot().WithSelectedItems(scope (item) =>
				{
					var activeItem = (SigActiveListViewItem)item;
					usedFormats.Add(activeItem.mEntry.DataFormat);
				});

			//Enum.GetEnumerator(); // SigPanel.DataFormat
			for (var value in Enum.GetEnumerator(typeof(SigPanel.DataFormat)))
			{
				if (value.value == 0)
					continue;

				var item = subMenu.AddItem(value.name);
				if (usedFormats.Contains((.)value.value))
					item.mIconImage = DarkTheme.sDarkTheme.GetImage(.Check);

				item.mOnMenuItemSelected.Add(new (menu) =>
					{
						mListView.GetRoot().WithSelectedItems(scope (item) =>
							{
								var activeItem = (SigActiveListViewItem)item;
								activeItem.mEntry.mDataFormat = (.)value.value;
								gApp.mSigPanel.UpdateValues();
							});
					});
			}

			menu.AddItem("Show in Selector");

			subMenu = menu.AddItem("Delete");
			subMenu.mOnMenuItemSelected.Add(new (menu) =>
				{
					var root = mListView.GetRoot();

					int checkIdx = 0;
					while (checkIdx < root.GetChildCount())
					{
						var listViewItem = (SigActiveListViewItem)root.GetChildAtIndex(checkIdx);
						if (listViewItem.Selected)
						{
							gApp.mSigPanel.mEntries.Remove(listViewItem.mEntry);
							delete listViewItem.mEntry;
							root.RemoveChildItemAt(checkIdx);
						}
						else
							checkIdx++;
					}
				});
		}
		else
		{
			var subMenu = menu.AddItem("Delete All");
			subMenu.mOnMenuItemSelected.Add(new (menu) =>
				{
					var root = mListView.GetRoot();
					int checkIdx = 0;
					while (root.GetChildCount() > 0)
					{
						var listViewItem = (SigActiveListViewItem)root.GetChildAtIndex(0);
						gApp.mSigPanel.mEntries.Remove(listViewItem.mEntry);
						delete listViewItem.mEntry;
						root.RemoveChildItemAt(checkIdx);
					}
				});
		}

		MenuWidget menuWidget = ThemeFactory.mDefault.CreateMenuWidget(menu);

		menuWidget.Init(relWidget, x, y);
		
		return menuWidget;
	}

	void ListViewItemClicked(ListViewItem item, float x, float y, int32 btnNum)
	{
		var item;
		if (item.mColumnIdx != 0)
		    item = item.GetSubItem(0);

		//mListView.GetRoot().SelectItemExclusively(item);

		if (btnNum == 1)
		{			
			float clickX = x;
			float clickY = item.mHeight + GS!(2);
		    float aX, aY;
		    item.SelfToOtherTranslate(mListView.GetRoot(), clickX, clickY, out aX, out aY);
		    ShowRightClickMenu(mListView, aX, aY, true);
		}
		else
		{                
		    //if (anItem.IsParent)
		        //anItem.Selected = false;
		}
	}

	void ListViewClicked(MouseEvent evt)
	{
		if (evt.mBtn == 1)
		{
		    //float aX, aY;
		    //evt.GetRootCoords(out aX, out aY);
		    ShowRightClickMenu(mListView, evt.mX, evt.mY, false);
		}
	}

	void ListViewMouseDown(MouseEvent evt)
	{
	    // We clicked off all items, so deselect
		//mListView.GetRoot().WithSelectedItems(scope (item) => { item.Selected = false; } );

		
	}

	public override void Resize(float x, float y, float width, float height)
	{
	    base.Resize(x, y, width, height);
	    mListView.Resize(0, 0, mWidth, mHeight);
	}

	public void RebuildListView()
	{
		var rootListViewItem = mListView.GetRoot();
		rootListViewItem.Clear();

		for (var item in mSigPanel.mEntries)
		{
			var listViewItem = rootListViewItem.CreateChildItem() as SigActiveListViewItem;
			listViewItem.mEntry = item;
			listViewItem.Label = item.mSignal.mName;
			listViewItem.AllowDragging = true;

			var subListViewItem = (SigActiveListViewItem)listViewItem.CreateSubItem(1);
			subListViewItem.AllowDragging = true;
			
			//var subListViewItem = listViewItem.CreateSubItem(1);
			//subListViewItem.Label = item.mName;
		}
	}

	public void RebuildEntriesFromListView()
	{
		var rootListViewItem = mListView.GetRoot();
		mSigPanel.mEntries.Clear();

		for (int idx < rootListViewItem.GetChildCount())
		{
			var listViewItem = (SigActiveListViewItem)rootListViewItem.GetChildAtIndex(idx);
			mSigPanel.mEntries.Add(listViewItem.mEntry);
		}
	}

	void HandleDragUpdate(DragEvent evt)
	{
	}

	void HandleDragEnd(DragEvent theEvent)
	{
	    if (theEvent.mDragKind == .None)
	        return;

		if (theEvent.mDragTarget is SigActiveListViewItem)
		{
		    var source = (SigActiveListViewItem)theEvent.mSender;
		    var target = (SigActiveListViewItem)theEvent.mDragTarget;

		    if (source.mListView == target.mListView)
		    {                    
		        if (source == target)
		            return;

				// We're dragging a top-level item into a new position
				source.mParentItem.RemoveChildItem(source, false);
				if (theEvent.mDragKind == .Before) // Before
				    target.mParentItem.InsertChild(source, target);
				else if (theEvent.mDragKind == .After) // After
				    target.mParentItem.AddChild(source, target);

				RebuildEntriesFromListView();
		    }
		}
	}

	public override void Draw(Graphics g)
	{
		g.DrawBox(DarkTheme.sDarkTheme.mImages[(int32)DarkTheme.ImageIdx.Window], 0, 0, mWidth, mHeight);
	}
}