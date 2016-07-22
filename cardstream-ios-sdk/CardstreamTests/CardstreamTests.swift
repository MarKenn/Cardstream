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
				"customerName": "Cardstream",
				"customerPhone": "+44 (0) 8450099575",
				"customerPostCode": "17T ST8",
				"type": "1" // E-commerce
			]
			
			let expectation = self.expectationWithDescription("asynchronous request")
			
			var secret: String?
			
			let httpRequest = try self.cardstreamDirect.directRequest(request, secret: &secret)
			
			let task = NSURLSession.sharedSession().dataTaskWithRequest(httpRequest, completionHandler: { data, _response, error in
				do {
					
					expectation.fulfill()
					
					let response = try self.cardstreamDirect.directRequestComplete(data!, response: _response, secret: secret)
					
					XCTAssertEqual((response["responseCode"]! as NSString).integerValue, Cardstream.Gateway.RC_SUCCESS)
					XCTAssertEqual(response["amountReceived"], request["amount"])
					XCTAssertEqual(response["state"], "captured")
					
				} catch Cardstream.Gateway.HTTPError.ClientError {
					XCTFail("HTTPError.ClientError")
				} catch Cardstream.Gateway.HTTPError.ServerError {
					XCTFail("HTTPError.ServerError")
				} catch Cardstream.Gateway.HTTPError.UnknownError {
					XCTFail("HTTPError.ClientError")
				} catch Cardstream.Gateway.ResponseError.IncorrectSignature {
					XCTFail("ResponseError.IncorrectSignature")
				} catch Cardstream.Gateway.ResponseError.IncorrectSignature1 {
					XCTFail("ResponseError.IncorrectSignature1")
				} catch Cardstream.Gateway.ResponseError.IncorrectSignature2 {
					XCTFail("ResponseError.IncorrectSignature2")
				} catch {
					XCTFail("Fail")
				}
			})
			
			task.resume()
			
			self.waitForExpectationsWithTimeout(60.0, handler: nil)
			
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
				"orderRef": "Signature Test",
				"transactionUnique": "55f025addd3c2",
				"type": "1" // E-commerce
			]
			
			let html = try self.cardstreamHosted.hostedRequest(request, options: ["submitText": "Confirm & Pay"])
			
			XCTAssertEqual(html, "<form method=\"post\"  action=\"https://gateway.cardstream.com/hosted/\">\n"
				+ "<input type=\"hidden\" name=\"action\" value=\"SALE\" />\n"
				+ "<input type=\"hidden\" name=\"amount\" value=\"2691\" />\n"
				+ "<input type=\"hidden\" name=\"cardExpiryDate\" value=\"1213\" />\n"
				+ "<input type=\"hidden\" name=\"cardNumber\" value=\"4929 4212 3460 0821\" />\n"
				+ "<input type=\"hidden\" name=\"countryCode\" value=\"826\" />\n"
				+ "<input type=\"hidden\" name=\"currencyCode\" value=\"826\" />\n"
				+ "<input type=\"hidden\" name=\"merchantID\" value=\"100001\" />\n"
				+ "<input type=\"hidden\" name=\"orderRef\" value=\"Signature Test\" />\n"
				+ "<input type=\"hidden\" name=\"signature\" value=\"d3e967258981e5e96724d51165b9332d18dfa20e3fed83ff2cb63b2ca208d513b8dd20d71610c3202f418f29cebf27c07c1ae614d07cc3ee2c3f3af28e688fd4|action,amount,cardExpiryDate,cardNumber,countryCode,currencyCode,merchantID,orderRef,transactionUnique,type\" />\n"
				+ "<input type=\"hidden\" name=\"transactionUnique\" value=\"55f025addd3c2\" />\n"
				+ "<input type=\"hidden\" name=\"type\" value=\"1\" />\n"
				+ "<input  type=\"submit\" value=\"Confirm &amp; Pay\">\n"
                + "<script>document.forms.submit();</script>\n"
                + "</form>\n")
			
		} catch {
			XCTFail("Fail")
		}
		
	}
	
}
