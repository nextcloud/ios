import Quick
import Nimble
@testable import Sheeeeeeeeet

class ActionSheet_PresenterTests: QuickSpec {
    
    override func spec() {
        
        describe("default presenter") {
            
            func getReversedIdiom() -> UIUserInterfaceIdiom {
                switch UIDevice.current.userInterfaceIdiom {
                case .phone: return .pad
                case .pad: return .phone
                default: return .unspecified
                }
            }
            
            it("is default presenter for current idiom") {
                let idiom = UIDevice.current.userInterfaceIdiom
                let idiomPresenter = idiom.defaultPresenter
                let defaultPresenter = ActionSheet.defaultPresenter
                let isSameKind = type(of: defaultPresenter) == type(of: idiomPresenter)
                
                expect(isSameKind).to(beTrue())
            }
            
            it("is different from other idioms") {
                let idiom = getReversedIdiom()
                let idiomPresenter = idiom.defaultPresenter
                let defaultPresenter = ActionSheet.defaultPresenter
                let isSameKind = type(of: defaultPresenter) == type(of: idiomPresenter)
                
                expect(isSameKind).to(beFalse())
            }
            
            it("is standard for iPhone") {
                let presenter = UIUserInterfaceIdiom.phone.defaultPresenter
                expect(presenter is ActionSheetStandardPresenter).to(beTrue())
            }
            
            it("is popover for iPad") {
                let presenter = UIUserInterfaceIdiom.pad.defaultPresenter
                expect(presenter is ActionSheetPopoverPresenter).to(beTrue())
            }
        }
    }
}
