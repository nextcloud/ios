//
//  CCNotification.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 27/01/17.
//  Copyright © 2017 TWS. All rights reserved.
//

import UIKit

class CCNotification: UITableViewController, UISearchResultsUpdating {


    var resultSearchController = UISearchController()
    
    override func viewDidLoad() {
        
        super.viewDidLoad()
        
        self.resultSearchController = ({

            let controller = UISearchController(searchResultsController: nil)
            
            controller.searchBar.sizeToFit()
            controller.searchResultsUpdater = self
            controller.dimsBackgroundDuringPresentation = false
            controller.searchBar.scopeButtonTitles = ["A", "B", "C", "D"]
            
            self.tableView.tableHeaderView = controller.searchBar
            
            return controller
        })()
        
        //aggiorniamo la tabella in caso ci fossero modifiche alla lista
        self.tableView.reloadData()
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        
        return 0
    }
    
    func updateSearchResults(for searchController: UISearchController) {
    }
}
