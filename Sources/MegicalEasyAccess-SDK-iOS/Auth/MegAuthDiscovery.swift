//
//  MegAuthDiscovery.swift
//  
//
//  Created by Antti Köliö on 11.2.2021.
//

import Foundation

@objc
public class MegAuthDiscovery: NSObject {
    
    static let IDP_DISCOVERY_PATH = "/.well-known/openid-configuration"
    
    @objc
    public class func oidConfiguration(authServerAddress: String,
                                       completion: @escaping ((_ openIdConfig: MegOpenIdConfiguration?,
                                                               _ error: Error?) -> ())) {
        guard var components = URLComponents(string: authServerAddress) else {
            completion(nil, EAErrorUtil.error(domain: "MegAuthDiscovery", code: -1, underlyingError: nil, description: "Bad authServerAddress: \(authServerAddress)"))
            return
        }
        components.path = IDP_DISCOVERY_PATH

        guard let discoveryEndpointUrl = components.url else {
            completion(nil, EAErrorUtil.error(domain: "MegAuthDiscovery", code: -1, underlyingError: nil, description: "Could not form discovery endpoint url"))
            return
        }
        
        let request = URLRequest(url: discoveryEndpointUrl)
        let task: URLSessionDataTask = URLSession.shared.dataTask(with: request) { (data: Data?,
                                                                                    response: URLResponse?,
                                                                                    error: Error?) in
            guard error == nil else {
                completion(nil, error)
                return
            }
            
            guard let httpResponse: HTTPURLResponse = response as? HTTPURLResponse else {
                completion(nil, EAErrorUtil.error(domain: "MegAuthDiscovery", code: -1, underlyingError: nil, description: "Response was not HTTPURLResponse"))
                return
            }
            
            if (httpResponse.statusCode != 200 && httpResponse.statusCode != 201) {
                completion(nil, EAErrorUtil.error(domain: "MegAuthDiscovery", code: -1, underlyingError: nil, description: "Response was not 200 or 201"))
                return
            }
            
            guard data != nil else {
                completion(nil, EAErrorUtil.error(domain: "MegAuthDiscovery", code: -1, underlyingError: nil, description: "No response data"))
                return
            }
            
            var jsonObject: [String: Any]
            do {
                jsonObject = try JSONSerialization.jsonObject(with: data!, options: .mutableContainers) as? [String: Any]  ?? [:]
            } catch {
                completion(nil, EAErrorUtil.error(domain: "MegAuthDiscovery", code: -1, underlyingError: error, description: "Could not parse result"))
                return
            }
            
            let oidConfig = MegOpenIdConfiguration.configuration(dict: jsonObject)
            completion(oidConfig, nil);
        }
        
        task.resume()
    }
}
