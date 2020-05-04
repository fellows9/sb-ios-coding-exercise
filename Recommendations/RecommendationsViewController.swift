//
//  ViewController.swift
//  Recommendations
//

import UIKit
import OHHTTPStubs

class RecommendationsViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    
    @IBOutlet weak var tableView: UITableView!
    
    var recommendations = [Recommendation]()
    
    lazy var recommendationsService = {
        return RecommendationsService()
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        recommendationsService.registerStub()

        if let cachedRecommendations = recommendationsService.retrieveCachedRecommendations() {
            recommendations = cachedRecommendations
        }
        
        setupTableView()
        fetchTitles()
    }
    
    private func setupTableView() {
        tableView.register(UINib(nibName: "RecommendationTableViewCell", bundle: nil), forCellReuseIdentifier: "Cell")
        tableView.dataSource = self
        tableView.delegate = self
    }
    
    private func fetchTitles() {
        recommendationsService.fetch { [weak self] (recommendations) in
            guard let self = self else { return }
            
            self.recommendations = recommendations
            
            DispatchQueue.main.async { [weak self] in
                self?.tableView.reloadData()
            }
        }
    }
        
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath) as? RecommendationTableViewCell {
            let recommendation = recommendations[indexPath.row]

            cell.titleLabel.text = recommendation.title
            cell.taglineLabel.text = recommendation.tagline
            cell.ratingLabel.text = "Rating: \(recommendation.rating)"
            
            if let url = recommendation.imageURL {
                DispatchQueue.global().async {
                    let data = try? Data(contentsOf: url)
                    if let imageData = data {
                        let image = UIImage(data: imageData)
                        DispatchQueue.main.async { [weak cell] in
                            cell?.recommendationImageView?.image = image
                        }
                    }
                }
            }

            return cell
        }
        
        return UITableViewCell()
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return recommendations.count
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return UITableView.automaticDimension
    }
}
