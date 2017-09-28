//
//  Copyright © 2016 Cardstream. All rights reserved.
//

import XCTest
@testable import Cardstream

class CardstreamTests: XCTestCase {
    
    let cardstreamDirect = Cardstream.Gateway("https://gateway.cardstream.com/direct/", "100001", "Circle4Take40Idea")
    let cardstreamHosted = Cardstream.Gateway("https://gateway.cardstream.com/hosted/", "100001", "Circle4Take40Idea")
    
    func testDirectRequest() {
        
        do {
            
            let request = [
                "action": "SALE",
                "amount": "1000",
                "cardCVV": "356",
                "cardExpiryMonth": "12",
                "cardExpiryYear": "15",
                "cardNumber": "4929421234600821",
                "countryCode": "826", // GB
                "currencyCode": "826", // GBP
                "customerAddress": "6347 Test Card Street",
                "customerName": "CardStream",
                "customerPhone": "+44 (0) 8450099575",
                "customerPostCode": "17T ST8",
                "orderRef": "iOS-SDK-TEST-DIRECT",
                "type": "1" // E-commerce
            ]
            
            let expectation = self.expectation(description: "asynchronous request")
            
            var secret: String?
            
            let httpRequest = try self.cardstreamDirect.directRequest(request, secret: &secret)
            let httpSession = URLSession.shared
            
            let task = httpSession.dataTask(with: httpRequest, completionHandler: { data, _response, error in
                do {
                    
                    expectation.fulfill()
                    
                    let response = try self.cardstreamDirect.directRequestComplete(data!, response: _response, secret: secret)
                    
                    XCTAssertEqual((response["responseCode"]! as NSString).integerValue, Cardstream.Gateway.RC_SUCCESS)
                    XCTAssertEqual(response["amountReceived"], request["amount"])
                    XCTAssertEqual(response["state"], "captured")
                    
                } catch Cardstream.Gateway.HTTPError.clientError {
                    XCTFail("HTTPError.ClientError")
                } catch Cardstream.Gateway.HTTPError.serverError {
                    XCTFail("HTTPError.ServerError")
                } catch Cardstream.Gateway.HTTPError.unknownError {
                    XCTFail("HTTPError.ClientError")
                } catch Cardstream.Gateway.ResponseError.incorrectSignature {
                    XCTFail("ResponseError.IncorrectSignature")
                } catch Cardstream.Gateway.ResponseError.incorrectSignature1 {
                    XCTFail("ResponseError.IncorrectSignature1")
                } catch Cardstream.Gateway.ResponseError.incorrectSignature2 {
                    XCTFail("ResponseError.IncorrectSignature2")
                } catch {
                    XCTFail("Fail")
                }
            })
            
            task.resume()
            
            self.waitForExpectations(timeout: 60.0, handler: nil)
            
        } catch {
            XCTFail("Fail")
        }
        
    }
    
    func testHostedRequest() {
        
        do {
            
            let request = [
                "action": "SALE",
                "amount": "2691",
                "cardExpiryDate": "1213",
                "cardNumber": "4929 4212 3460 0821",
                "countryCode": "826", // GB
                "currencyCode": "826", // GBP
                "merchantID": "100001",
                "orderRef": "iOS-SDK-TEST-HOSTED",
                "transactionUnique": "55f025addd3c2",
                "type": "1" // E-commerce
            ]
            
            let html = try self.cardstreamHosted.hostedRequest(request, options: ["submitText": "Confirm & Pay"])
            
            let signature = self.cardstreamHosted.sign(request, secret: "Circle4Take40Idea", partial: true)
            
            XCTAssertEqual(html, "<form method=\"post\"  action=\"https://gateway.cardstream.com/hosted/\">\n"
                + "<input type=\"hidden\" name=\"action\" value=\"SALE\" />\n"
                + "<input type=\"hidden\" name=\"amount\" value=\"2691\" />\n"
                + "<input type=\"hidden\" name=\"cardExpiryDate\" value=\"1213\" />\n"
                + "<input type=\"hidden\" name=\"cardNumber\" value=\"4929 4212 3460 0821\" />\n"
                + "<input type=\"hidden\" name=\"countryCode\" value=\"826\" />\n"
                + "<input type=\"hidden\" name=\"currencyCode\" value=\"826\" />\n"
                + "<input type=\"hidden\" name=\"merchantID\" value=\"100001\" />\n"
                + "<input type=\"hidden\" name=\"orderRef\" value=\"iOS-SDK-TEST-HOSTED\" />\n"
                + "<input type=\"hidden\" name=\"signature\" value=\"" + signature + "\" />\n"
                + "<input type=\"hidden\" name=\"transactionUnique\" value=\"55f025addd3c2\" />\n"
                + "<input type=\"hidden\" name=\"type\" value=\"1\" />\n"
                + "<input  type=\"submit\" value=\"Confirm &amp; Pay\">\n"
                + "</form>\n")
            
        } catch {
            XCTFail("Fail")
        }
        
    }
    
}

