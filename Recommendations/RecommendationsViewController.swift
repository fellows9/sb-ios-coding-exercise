//
//  ViewController.swift
//  Recommendations
//

import UIKit
import OHHTTPStubs

struct Response: Codable {
    var titlesOwned: [String]
    var titles: [Recommendation]
    var titlesSkipped: [String]
    
    enum CodingKeys: String, CodingKey {
        case titlesOwned = "titles_owned"
        case titles = "titles"
        case titlesSkipped = "skipped"
    }

    init(from decoder: Decoder) throws{
        let container = try decoder.container(keyedBy: CodingKeys.self)
        titlesOwned = try container.decode([String].self, forKey: .titlesOwned)
        titles = try container.decode([Recommendation].self, forKey: .titles)
        titlesSkipped = try container.decode([String].self, forKey: .titlesSkipped)
    }

}

struct Recommendation: Codable {
    var title: String = ""
    var tagline: String = ""
    var imageURL: URL?
    var isReleased: Bool = false
    var rating: Float = 0.0
    
    enum CodingKeys: String, CodingKey {
        case title = "title"
        case tagline = "tagline"
        case imageURL = "image"
        case isReleased = "is_released"
        case rating = "rating"
    }
    
    init(from decoder: Decoder) throws{
        let container = try decoder.container(keyedBy: CodingKeys.self)
        title = try container.decodeIfPresent(String.self, forKey: .title) ?? ""
        tagline = try container.decodeIfPresent(String.self, forKey: .tagline) ?? ""
        imageURL = try container.decodeIfPresent(URL.self, forKey: .imageURL)
        isReleased = try container.decodeIfPresent(Bool.self, forKey: .isReleased) ?? false
        rating = try container.decodeIfPresent(Float.self, forKey: .rating) ?? 0.0
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(title, forKey: .title)
        try container.encode(tagline, forKey: .tagline)
        try container.encodeIfPresent(imageURL, forKey: .imageURL)
        try container.encode(isReleased, forKey: .isReleased)
        try container.encode(rating, forKey: .rating)
    }
}


class RecommendationsViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    
    @IBOutlet weak var tableView: UITableView!
    
    var recommendations = [Recommendation]()
    let recommendationsKey = "recommendations"
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if let recommendationsData = UserDefaults.standard.data(forKey: recommendationsKey),
            let cachedRecommendations = try? JSONDecoder().decode([Recommendation].self, from: recommendationsData) {
            recommendations = cachedRecommendations
        }
        // ---------------------------------------------------
        // -------- <DO NOT MODIFY INSIDE THIS BLOCK> --------
        // stub the network response with our local ratings.json file
        let stub = Stub()
        stub.registerStub()
        // -------- </DO NOT MODIFY INSIDE THIS BLOCK> -------
        // ---------------------------------------------------
        
        tableView.register(UINib(nibName: "RecommendationTableViewCell", bundle: nil), forCellReuseIdentifier: "Cell")
        tableView.dataSource = self
        tableView.delegate = self
        
        fetchTitles()
    }
    
    private func fetchTitles() {
        // NOTE: please maintain the stubbed url we use here and the usage of
        // a URLSession dataTask to ensure our stubbed response continues to
        // work; however, feel free to reorganize/rewrite/refactor as needed
        guard let url = URL(string: Stub.stubbedURL_doNotChange) else { fatalError() }
        let request = URLRequest(url: url)
        let session = URLSession(configuration: .default)

        let task = session.dataTask(with: request, completionHandler: { [weak self] (data, response, error) in
            guard let receivedData = data, let self = self else { return }
            
            // TASK: This feels gross and smells. Can this json parsing be made more robust and extensible?
            do {
                let responseObject = try JSONDecoder().decode(Response.self, from: receivedData)
                self.updateRecommendations(with: responseObject)
            }
            catch {
                fatalError("Error parsing stubbed json data: \(error)")
            }
        });

        task.resume()
    }
    
    private func updateRecommendations(with response: Response) {
        let sortedTitles = response.titles.sorted { $0.rating > $1.rating }

        //Should include only released titles, and excludes titles without a rating, skipped titles, and titles already owned
        let filteredTitles = sortedTitles.filter { (recommendation) -> Bool in
            return recommendation.isReleased
                && recommendation.rating != 0.0
                && !response.titlesSkipped.contains(recommendation.title)
                && !response.titlesOwned.contains(recommendation.title)
        }
        let arrayMax = filteredTitles.count > 10 ? 10 : filteredTitles.count
        let topTitles = Array(filteredTitles[0..<arrayMax])
        if let recommendationsData = try? JSONEncoder().encode(topTitles) {
            UserDefaults.standard.setValue(recommendationsData, forKeyPath: recommendationsKey)
        }
        recommendations = topTitles

        DispatchQueue.main.async {
            self.tableView.reloadData()
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
