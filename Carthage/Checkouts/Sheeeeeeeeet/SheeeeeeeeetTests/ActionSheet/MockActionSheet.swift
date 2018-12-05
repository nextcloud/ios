import Sheeeeeeeeet

class MockActionSheet: ActionSheet {
    
    var dismissInvokeCount = 0
    var handleTapInvokeCount = 0
    var handleTapInvokeItems = [ActionSheetItem]()
    var prepareForPresentationInvokeCount = 0
    var refreshInvokeCount = 0
    var refreshButtonsVisibilityInvokeCount = 0
    var refreshHeaderVisibilityInvokeCount = 0
    var reloadDataInvokeCount = 0
    
    override func dismiss(completion: @escaping () -> ()) {
        super.dismiss { completion() }
        dismissInvokeCount += 1
    }
    
    override func handleTap(on item: ActionSheetItem) {
        super.handleTap(on: item)
        handleTapInvokeCount += 1
        handleTapInvokeItems.append(item)
    }
    
    override func refresh() {
        super.refresh()
        refreshInvokeCount += 1
    }
    
    override func refreshButtonsVisibility() {
        super.refreshButtonsVisibility()
        refreshButtonsVisibilityInvokeCount += 1
    }
    
    override func refreshHeaderVisibility() {
        super.refreshHeaderVisibility()
        refreshHeaderVisibilityInvokeCount += 1
    }
    
    override func reloadData() {
        super.reloadData()
        reloadDataInvokeCount += 1
    }
}
