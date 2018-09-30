//
//  DBCapabilitiesCache.swift
//  BeagleIM
//
//  Created by Andrzej Wójcik on 26/09/2018.
//  Copyright © 2018 HI-LOW. All rights reserved.
//

import Foundation
import TigaseSwift

class DBCapabilitiesCache: CapabilitiesCache {
    
    public static let instance = DBCapabilitiesCache();
    
    public let dispatcher: QueueDispatcher;

    fileprivate var getFeatureStmt: DBStatement;
    fileprivate var getIdentityStmt: DBStatement;
    fileprivate var getNodesWithFeatureStmt: DBStatement;
    fileprivate var insertFeatureStmt: DBStatement;
    fileprivate var insertIdentityStmt: DBStatement;
    fileprivate var nodeIsCached: DBStatement;

    fileprivate var features = [String: [String]]();
    fileprivate var identities: [String: DiscoveryModule.Identity] = [:];
    
    fileprivate init() {
        getFeatureStmt = try! DBConnection.main.prepareStatement("SELECT feature FROM caps_features WHERE node = :node");
        getIdentityStmt = try! DBConnection.main.prepareStatement("SELECT name, category, type FROM caps_identities WHERE node = :node");
        getNodesWithFeatureStmt = try! DBConnection.main.prepareStatement("SELECT node FROM caps_features WHERE feature = :features");
        insertFeatureStmt = try! DBConnection.main.prepareStatement("INSERT INTO caps_features (node, feature) VALUES (:node, :feature)");
        insertIdentityStmt = try! DBConnection.main.prepareStatement("INSERT INTO caps_identities (node, name, category, type) VALUES (:node, :name, :category, :type)");
        nodeIsCached = try! DBConnection.main.prepareStatement("SELECT count(feature) FROM caps_features WHERE node = :node");
        dispatcher = QueueDispatcher(label: "DBCapabilitiesCache");
    }

    open func getFeatures(for node: String) -> [String]? {
        return dispatcher.sync {
            guard let features = self.features[node] else {
                let features: [String] = try! self.getFeatureStmt.query(node) {cursor in cursor["feature"]! };
                guard !features.isEmpty else {
                    return nil;
                }
                self.features[node] = features;
                return features;
            }
            return features;
        }
    }
    
    open func getIdentity(for node: String) -> DiscoveryModule.Identity? {
        return dispatcher.sync {
            guard let identity = self.identities[node] else {
                guard let (category, type, name): (String?, String?, String?) = try! self.getIdentityStmt.findFirst(node, map: { cursor in
                    return (cursor["category"], cursor["type"], cursor["name"]);
                }) else {
                    return nil;
                }
                
                let identity = DiscoveryModule.Identity(category: category!, type: type!, name: name);
                self.identities[node] = identity;
                return identity;
            }
            return identity;
        }
    }
    
    open func getNodes(withFeature feature: String) -> [String] {
        return dispatcher.sync {
            return try! self.getNodesWithFeatureStmt.query(feature) { cursor in cursor["node"]! };
        }
    }
    
    open func isCached(node: String, handler: @escaping (Bool)->Void) {
        dispatcher.async {
            handler(self.isCached(node: node));
        }
    }
    
    open func store(node: String, identity: DiscoveryModule.Identity?, features: [String]) {
        dispatcher.async {
            guard !self.isCached(node: node) else {
                return;
            }
            
            self.features[node] = features;
            self.identities[node] = identity;
            
            for feature in features {
                _ = try! self.insertFeatureStmt.insert(node, feature);
            }
            
            if identity != nil {
                _ = try! self.insertIdentityStmt.insert(node, identity!.name, identity!.category, identity!.type);
            }
        }
    }
    
    fileprivate func isCached(node: String) -> Bool {
        do {
            let val = try self.nodeIsCached.scalar(node) ?? 0;
            return val != 0;
        } catch {
            // it is better to assume that we have features...
            return true;
        }
    }

}