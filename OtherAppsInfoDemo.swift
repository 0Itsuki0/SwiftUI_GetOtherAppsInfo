
import SwiftUI


struct OtherAppsInfoDemo: View {
    @State private var searchText: String = "com.spotify.client"
    // search result by bundle id or app id will be unique
    @State private var searchResult: SearchResult? = nil
    @State private var isLoading: Bool = false
    @State private var error: Error? = nil
    @State private var useBundleId: Bool = true
    @State private var searchPresented: Bool = false
    
    private let urlString = "https://itunes.apple.com/lookup"

    private var trimmedText: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    var body: some View {
        NavigationStack {
            List {
                Picker(selection: $useBundleId, content: {
                    Text("Bundle Id")
                        .tag(true)
                    Text("App Id")
                        .tag(false)
                }, label: {})
                    .pickerStyle(.segmented)
                    .listRowBackground(Color.clear)
                
                if let error {
                    Text(error.localizedDescription)
                        .foregroundStyle(.red)
                }
                
                if let searchResult {
                    VStack(alignment: .leading, spacing: 16, content: {
                        HStack(spacing: 16) {
                            let url = searchResult.artworkUrl512 ?? searchResult.artworkUrl100 ?? searchResult.artworkUrl60
                            
                            Group {
                                if let url {
                                    AsyncImage(url: url, scale: 1.0, content: { image in
                                        image
                                            .resizable().scaledToFit()
                                            .aspectRatio(1.0, contentMode: .fit)
                                    }, placeholder: {
                                        ProgressView()
                                    })
                                } else {
                                    Image(systemName: "camera.metering.unknown")
                                        .resizable().scaledToFit()
                                        .aspectRatio(1.0, contentMode: .fit)
                                }
                            }
                            .frame(width: 64)
                            
                            VStack(alignment: .leading, spacing: 8, content:  {
                                Text("\(searchResult.trackName, default: "(unknown)")")
                                    .font(.headline)
                                Text("By: \(searchResult.sellerName, default: "(unknown)")")
                                    .foregroundStyle(.secondary)
                            })
                        }
                        
                        Group {
                            Text("\(searchResult.description, default: "(unknown)")")
                            
                            Divider()
                            Text("Average Rating: \(searchResult.averageUserRating?.formatted(.number.precision(.fractionLength(1))), default: "(unknown)")")
                            Text("Price: \(searchResult.price, default: "(unknown)")")
                            Text("Bundle Id: \(searchResult.bundleId, default: "(unknown)")")
                            Text("Genres: \(searchResult.genres?.joined(separator: ","), default: "(unknown)")")
                            Text("Version: \(searchResult.version, default: "(unknown)")")
                        }

                    })
                    .font(.subheadline)
                }
            }
            .contentMargins(.top, 8)
            .listRowSpacing(16)
            .navigationTitle("Get App Info")
            .searchable(text: $searchText, isPresented: $searchPresented, placement: .navigationBarDrawer, prompt: Text("App Id or Bundle Id"))
            .overlay(content: {
                if isLoading {
                    ProgressView()
                        .controlSize(.extraLarge)
                } else {
                    if searchResult == nil {
                        ContentUnavailableView("No results", systemImage: "magnifyingglass")
                    }
                }
            })
            .onSubmit(of: .search, {
                self.searchPresented = false
                self.useBundleId ? self.searchByBundleId() : self.searchByAppId()
            })
            .onChange(of: self.useBundleId, {
                self.searchText = self.useBundleId ? "com.spotify.client" : "535886823"
            })
        }
    }
    
    private func searchByBundleId() {
        guard !trimmedText.isEmpty else { return }
        guard let url = URL(string: "\(urlString)?bundleId=\(trimmedText)") else {
            return
        }
        self.search(url: url)
    }
    
    private func searchByAppId() {
        guard !trimmedText.isEmpty else { return }
        guard let url = URL(string: "\(urlString)?id=\(trimmedText)") else {
            return
        }
        self.search(url: url)
    }
    
    private func search(url: URL) {
        self.error = nil
        self.searchResult = nil
        Task {
            self.isLoading = true
            do {
                let data = try await NetworkService.sendURLRequest(url: url , method: "GET", headers: [:], body: nil)
                let decoded = try NetworkService.decode(ITunesSearchResponse.self, from: data)
                self.searchResult = decoded.results.first
            } catch(let error) {
                self.error = error
            }
            
            self.isLoading = false
        }

    }
}

// MARK: Response Data model

// root
struct ITunesSearchResponse: Codable {
    let resultCount: Int
    let results: [SearchResult]
}

// individual result
struct SearchResult: Codable {
    let artistViewUrl: URL?
    let artworkUrl60: URL?
    let artworkUrl100: URL?
    let artworkUrl512: URL?
    
    let features: [String]?
    let supportedDevices: [String]?
    let advisories: [String]?
    
    let isGameCenterEnabled: Bool?
    let kind: String?
    
    let screenshotUrls: [String]?
    let ipadScreenshotUrls: [String]?
    let appletvScreenshotUrls: [String]?
    
    let minimumOsVersion: String?
    let averageUserRating: Double?
    let trackCensoredName: String?
    let trackViewUrl: String?
    let contentAdvisoryRating: String?
    
    let genres: [String]?
    let genreIds: [String]?
    
    let artistId: Int?
    let artistName: String?
    
    let price: Double?
    let bundleId: String?
    let sellerName: String?
    
    let releaseDate: String?
    let currentVersionReleaseDate: String?
    
    let primaryGenreName: String?
    let primaryGenreId: Int?
    
    let releaseNotes: String?
    let version: String?
    let wrapperType: String?
    let currency: String?
    let description: String?
    
    let languageCodesISO2A: [String]?
    let fileSizeBytes: String?
    let formattedPrice: String?
    
    let userRatingCountForCurrentVersion: Int?
    let trackContentRating: String?
    let averageUserRatingForCurrentVersion: Double?
    let sellerUrl: String?
    let userRatingCount: Int?
    
    let trackId: Int?
    let trackName: String?
}


// MARK: Networking
private extension HTTPURLResponse {
    var isSuccess: Bool {
        return (200...299).contains(self.statusCode)
    }
}

private enum NetworkError: Error, LocalizedError {
    case failToCreateURL
    case badResponse(code: Int)
    case dataTaskError(Error)

    var errorDescription: String? {
        switch self {
        case .failToCreateURL:
            "Fail to create URL."
        case .badResponse(let code):
            "Network failed. Code:\(code)."
        case .dataTaskError(let error):
            "Error making network request: \(error.localizedDescription)"
        }
    }
}


private final class NetworkService {
    private init() {}

    static func sendURLRequest(
        url: URL,
        method: String,
        headers: [String: String],
        body: Data?,
    ) async throws -> Data {
        var request = URLRequest(url: url)

        request.httpMethod = method

        request.allHTTPHeaderFields = headers
        request.httpBody = body

        do {
            let (data, response) = try await URLSession.shared.data(
                for: request
            )
            let httpResponse = response as? HTTPURLResponse
            if let httpResponse, !httpResponse.isSuccess {
                
                // self.logError("\(String(data: data, encoding: .utf8) ?? "Unknown Error in networking.")")
                
                throw NetworkError.badResponse(
                    code: httpResponse.statusCode
                )
            }
            return data
        } catch (let error) {
            throw NetworkError.dataTaskError(error)
        }

    }

    static func decode<T>(_ type: T.Type, from data: Data) throws -> T
    where T: Decodable {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        do {
            let decodedResponse = try decoder.decode(T.self, from: data)
            return decodedResponse
        } catch (let error) {
            throw error
        }
    }
}
