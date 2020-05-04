//
//  RecommendationsService.swift
//  Recommendations
//
//  Created by Steven Fellows on 5/4/20.
//  Copyright © 2020 Serial Box. All rights reserved.
//

import Foundation

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

class RecommendationsService: NSObject {

    let recommendationsKey = "recommendations"

    func retrieveCachedRecommendations() -> [Recommendation]? {
        if let recommendationsData = UserDefaults.standard.data(forKey: recommendationsKey),
            let recommendations = try? JSONDecoder().decode([Recommendation].self, from: recommendationsData) {
            return recommendations
        }
        
        return nil
    }
    
    func fetch(_ completion: @escaping (_ recommendations: [Recommendation]) -> Void) {
        guard let url = URL(string: Stub.stubbedURL_doNotChange) else { fatalError() }
        let request = URLRequest(url: url)
        let session = URLSession(configuration: .default)

        let task = session.dataTask(with: request, completionHandler: { [weak self] (data, response, error) in
            guard let receivedData = data, let self = self else {
                completion([])
                return
            }
            
            do {
                let response = try JSONDecoder().decode(Response.self, from: receivedData)
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
                    UserDefaults.standard.setValue(recommendationsData, forKeyPath: self.recommendationsKey)
                }
                completion(topTitles)
            } catch {
                completion([])
                fatalError("Error parsing stubbed json data: \(error)")
            }
        });

        task.resume()

    }
    
    func registerStub() {
        // ---------------------------------------------------
        // -------- <DO NOT MODIFY INSIDE THIS BLOCK> --------
        // stub the network response with our local ratings.json file
        let stub = Stub()
        stub.registerStub()
        // -------- </DO NOT MODIFY INSIDE THIS BLOCK> -------
        // ---------------------------------------------------
    }

}
