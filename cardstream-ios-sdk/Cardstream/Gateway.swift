//
//  Cardstream Payment Gateway SDK.
//

import Crypto

///
/// Class to communicate with Payment Gateway.
///
public class Gateway {
	
	/// Transaction successful reponse code
	public static let RC_SUCCESS = 0
	
	/// Transaction declined reponse code
	public static let RC_DO_NOT_HONOR = 5
	
	/// Verification successful reponse code
	public static let RC_NO_REASON_TO_DECLINE = 85
	
	public static let RC_3DS_AUTHENTICATION_REQUIRED = 0x1010A
	
	static let REMOVE_REQUEST_FIELDS = [
		"directUrl",
		"hostedUrl",
		"merchantAlias",
		"merchantID2",
		"merchantSecret",
		"responseCode",
		"responseMessage",
		"responseStatus",
		"signature",
		"state",
		]
	
	/// HTTP protocol errors
	public enum HTTPError: ErrorType {
		case ClientError
		case ServerError
		case UnknownError
	}
	
	/// Request errors
	public enum RequestError: ErrorType {
		case MissingAction
		case MissingMerchantID
	}
	
	/// Response errors
	public enum ResponseError: ErrorType {
		case IncorrectSignature
		case IncorrectSignature1
		case IncorrectSignature2
		case MissingResponseCode
	}
	
	let gatewayUrl: NSURL!
	let merchantID: String
	let merchantSecret: String?
	let merchantPwd: String?
	
	///
	/// Configure the Payment Gateway interface.
	///
	/// - Parameter gatewayUrl: Gateway API Endpoint (Direct or Hosted)
	/// - Parameter merchantID: Merchant Account Id or Alias
	/// - Parameter merchantSecret: Secret for above Merchant Account
	/// - Parameter merchantPwd: Password for above Merchant Account
	///
	public init(_ gatewayUrl: String, _ merchantID: String, _ merchantSecret: String?, merchantPwd: String? = nil) {
		self.gatewayUrl = NSURL(string: gatewayUrl)
		self.merchantID = merchantID
		self.merchantSecret = merchantSecret
		self.merchantPwd = merchantPwd
	}
	
	///
	/// Send request to Gateway using HTTP Direct API.
	///
	/// The method will create a NSURLRequest to send to Gateway using HTTP Direct API.
	///
	/// The request will use the following Gateway properties unless alternative
	/// values are provided in the request:
	///
	/// - 'directUrl'      - Gateway Direct API Endpoint
	/// - 'merchantID'     - Merchant Account Id or Alias
	/// - 'merchantPwd'    - Merchant Account Password
	/// - 'merchantSecret' - Merchant Account Secret
	///
	/// The method will sign the request and also check the signature on any
	/// response.
	///
	/// The method will throw an exception if it is unable to send the request
	/// or receive the response.
	///
	/// The method does not attempt to validate any request fields.
	///
	/// - Parameter request: request data
	/// - Parameter secret: any extracted 'merchantSecret' (return)
	/// - Parameter options: options
	/// - Returns: NSURLRequest ready for sending
	/// - Throws: RequestError invalid request data
	///
	public func directRequest(request: [String: String], options: [String: String] = [:], inout secret: String?) throws -> NSURLRequest {
		
		let directUrl: NSURL
		
		if let _directUrl = request["directUrl"] {
			directUrl = NSURL(string: _directUrl)!
		} else {
			directUrl = self.gatewayUrl
		}
		
		secret = request["merchantSecret"] ?? self.merchantSecret
		
		var _request = try self.prepareRequest(request, options: options)
		
		if secret != nil {
			_request["signature"] = self.sign(_request, secret: secret)
		}
		
		let data = Gateway.buildQueryString(_request).dataUsingEncoding(NSUTF8StringEncoding)!
		
		let httpRequest = NSMutableURLRequest(URL: directUrl)
		
		httpRequest.HTTPMethod = "POST"
		httpRequest.setValue("application/x-www-form-urlencoded; charset=utf-8", forHTTPHeaderField: "Content-Type")
		httpRequest.setValue(String(data.length), forHTTPHeaderField: "Content-Length")
		httpRequest.HTTPBody = data
		
		return httpRequest
		
	}
	
	///
	/// Handle a NSURLResponse received from the gateway.
	///
	/// - Parameter data: data returned by the server
	/// - Parameter response: response meta-data
	/// - Parameter secret: secret to use in signing
	/// - Returns: verified response data
	/// - Throws: HTTPError communications failure
	///
	public func directRequestComplete(data: NSData, response: NSURLResponse? = nil, secret: String? = nil) throws -> [String: String] {
		
		if let httpResponse = response as? NSHTTPURLResponse {
			switch httpResponse.statusCode {
			case 200:
				break
			case 300...399:
				throw HTTPError.ClientError
			case 400...499:
				throw HTTPError.ServerError
			default:
				throw HTTPError.UnknownError
			}
		}
		
		let _data = String(data: data, encoding: NSUTF8StringEncoding)!
		
		let _response = Gateway.parseQueryString(_data)
		
		return try self.verifyResponse(_response, secret: secret)
		
	}
	
	///
	/// Send request to Gateway using HTTP Hosted API.
	///
	/// The method will send a request to the Gateway using the HTTP Hosted API.
	///
	/// The request will use the following Gateway properties unless alternative
	/// values are provided in the request:
	/// - 'hostedUrl':      Gateway Hosted API Endpoint
	/// - 'merchantID':     Merchant Account Id or Alias
	/// - 'merchantPwd':    Merchant Account Password
	/// - 'merchantSecret': Merchant Account Secret
	///
	/// The method accepts the following options:
	/// - 'formAttrs':      HTML form attributes
	/// - 'submitAttrs':    HTML submit button attributes
	/// - 'submitImage':    Image to use as the Submit button
	/// - 'submitHtml':     HTML to show on the Submit button
	/// - 'submitText':     Text to show on the Submit button
	///
	/// 'submitImage', 'submitHtml' and 'submitText' are mutually exclusive
	/// options and will be checked for in that order. If none are provided
	/// the submitText='Pay Now' is assumed.
	///
	/// The method will sign the request; partial signing will be used to allow
	/// for submit button images et cetera.
	///
	/// The method returns the HTML fragment that needs including in order to
	/// send the request.
	///
	/// The method does not attempt to validate any request fields.
	///
	/// - Parameter request: request data
	/// - Parameter options: options
	/// - Returns: request HTML form
	/// - Throws: RequestError invalid request data
	///
	public func hostedRequest(request: [String: String], options: [String: String] = [:]) throws -> String {
		
		let hostedUrl: NSURL
		
		if let _hostedUrl = request["hostedUrl"] {
			hostedUrl = NSURL(string: _hostedUrl)!
		} else {
			hostedUrl = self.gatewayUrl
		}
		
		let secret = request["merchantSecret"] ?? self.merchantSecret
		
		var _request = try self.prepareRequest(request, options: options)
		
		if secret != nil {
			_request["signature"] = self.sign(_request, secret: secret, partial: true)
		}
		
		var form = "<form method=\"post\" "
		
		if let formAttrs = options["formAttrs"] {
			form += formAttrs
		}
		
		form += " action=\"" + htmlencode(hostedUrl.absoluteString) + "\">\n"
		
		for name in Array(_request.keys).sort() {
			form += self.fieldToHtml(name, value: _request[name]!)
		}
		
		if options["submitHtml"] != nil {
			form += "<button type=\"submit\" "
		} else {
			form += "<input "
		}
		
		if let submitAttrs = options["submitAttrs"] {
			form += submitAttrs
		}
		
		if let submitImage = options["submitImage"] {
			form += " type=\"image\" src=\"" + htmlencode(submitImage) + "\">\n"
		} else if let submitHtml = options["submitHtml"] {
			form += ">" + submitHtml + "</button>\n"
		} else if let submitText = options["submitText"] {
			form += " type=\"submit\" value=\"" + htmlencode(submitText) + "\">\n"
		} else {
			form += " type=\"submit\" value=\"Pay Now\">\n"
		}
		form += "<script>document.forms.submit();</script>\n"
		form += "</form>\n"
		
		return form
		
	}
	
	///
	/// Prepare a request for sending to the Gateway.
	///
	/// The method will insert the following configuration properties into
	/// the request if they are not already present:
	///
	/// - merchantID: Merchant Account Id or Alias
	/// - merchantPwd: Merchant Account Password (if provided)
	///
	/// The method will throw an exception if the request doesn't contain
	/// an 'action' element or a 'merchantID' element (and none could be
	/// inserted).
	///
	/// The method does not attempt to validate any request fields.
	///
	/// - Parameter request: request data
	/// - Parameter options: options
	/// - Returns: request data ready for sending
	/// - Throws: RequestError invalid request data
	///
	public func prepareRequest(request: [String: String], options: [String: String] = [:]) throws -> [String: String] {
		
		guard request["action"] != nil else {
			throw RequestError.MissingAction
		}
		
		var _request = request
		
		if _request["merchantID"] == nil {
			_request["merchantID"] = self.merchantID
		}
		
		if self.merchantPwd != nil && _request["merchantPwd"] == nil {
			_request["merchantPwd"] = self.merchantPwd
		}
		
		guard _request["merchantID"] != nil else {
			throw RequestError.MissingMerchantID
		}
		
		for name in Gateway.REMOVE_REQUEST_FIELDS {
			_request.removeValueForKey(name)
		}
		
		return _request
		
	}
	
	///
	/// Verify the response from the Gateway.
	///
	/// This method will verify that the response is present, contains a
	/// response code and is correctly signed if a secret is available.
	///
	/// If the response is invalid then an exception will be thrown.
	///
	/// Any signature is removed from the passed response.
	///
	/// - Parameter response: response to verify
	/// - Parameter secret: secret to use in signing
	/// - Returns: verified response data
	/// - Throws: ResponseError invalid response data
	///
	public func verifyResponse(response: [String: String], secret: String? = nil) throws -> [String: String] {
		
		guard response["responseCode"] != nil else {
			throw ResponseError.MissingResponseCode
		}
		
		let secret = secret ?? self.merchantSecret
		
		var _response = response
		var signature = _response.removeValueForKey("signature")
		var partial: String? = nil
		
		if let _signature = signature {
			if _signature.containsString("|") {
				
				let components = _signature.componentsSeparatedByString("|")
				
				signature = components[0]
				partial = components[1]
				
			}
		}
		
		if secret == nil && signature != nil {
			// Signature present when not expected (Gateway has a secret but we don't)
			throw ResponseError.IncorrectSignature1
		}
		
		if secret != nil && signature == nil {
			// Signature missing when one expected (we have a secret but the Gateway doesn't)
			throw ResponseError.IncorrectSignature2
		}
		
		if secret != nil && self.sign(_response, secret: secret, partial: partial) != signature {
			// Signature mismatch
			throw ResponseError.IncorrectSignature
		}
		
		return _response
	}
	
	///
	/// Sign the given array of data.
	///
	/// This method will return the correct signature for the data array.
	///
	/// If the secret is not provided then merchantSecret is used.
	///
	/// The partial parameter is used to indicate that the signature should
	/// be marked as 'partial' and can take three possible value types as
	/// follows:
	///
	/// - boolean: sign with all fields
	/// - string:  comma separated list of field names to sign
	/// - array:   array of field names to sign
	///
	/// - Parameter data: data to sign
	/// - Parameter secret: secret to use in signing
	/// - Parameter partial: partial signing
	/// - Returns: signature
	///
	public func sign(data: [String: String], secret: String? = nil, partial: Any? = nil) -> String {
		
		let secret = secret ?? self.merchantSecret
		
		var _data = data
		
		let _partial: String?
		
		if partial != nil {
			
			let arrayPartial: [String]?
			
			if let _stringPartial = partial as? String {
				arrayPartial = _stringPartial.componentsSeparatedByString(",")
			} else if let _arrayPartial = partial as? [String] {
				arrayPartial = _arrayPartial
			} else {
				arrayPartial = nil
			}
			
			if arrayPartial != nil {
				for name in arrayPartial! {
					_data.removeValueForKey(name)
				}
			}
			
			_partial = Array(_data.keys).sort().joinWithSeparator(",")
			
		} else {
			_partial = nil
		}
		
		let message = Gateway.buildQueryString(data) + secret!
		
		let signature = message.SHA512!
		
		if let partial = _partial {
			return signature + "|" + partial
		}
		
		return signature
		
	}
	
	///
	/// Return the field name and value as HTML input tags.
	///
	/// The method will return a string containing one or more HTML <input
	/// type="hidden"> tags which can be used to store the name and value.
	///
	/// - Parameter name: field name
	/// - Parameter value: field value
	/// - Returns: HTML containing <INPUT> tags
	///
	public func fieldToHtml(name: String, value: String) -> String {
		
		if value.isEmpty {
			return ""
		}
		
		let name = htmlencode(name)
		let value = htmlencode(value)
		
		return "<input type=\"hidden\" name=\"\(name)\" value=\"\(value)\" />\n"
		
	}
	
	class func buildQueryString(data: [String: String]) -> String {
		
		let allowedCharacters = NSCharacterSet(charactersInString: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~")
		
		var items = [String]()
		
		for name in Array(data.keys).sort() {
			
			let _name = name.stringByAddingPercentEncodingWithAllowedCharacters(allowedCharacters)!
			let _value = data[name]!.stringByAddingPercentEncodingWithAllowedCharacters(allowedCharacters)!
			
			items.append("\(_name)=\(_value)")
			
		}
		
		var query = items.joinWithSeparator("&")
		
		if let regex = try? NSRegularExpression(pattern: "%0D%0A|%0A%0D|%0D", options: .CaseInsensitive) {
			query = regex.stringByReplacingMatchesInString(query, options: .WithTransparentBounds, range: NSMakeRange(0, query.characters.count), withTemplate: "%0A")
		}
		
		return query.stringByReplacingOccurrencesOfString("%20", withString: "+")
		
	}
	
	class func parseQueryString(query: String) -> [String: String] {
		
		var data = [String: String]()
		
		for pair in query.componentsSeparatedByString("&") {
			
			let item = pair.componentsSeparatedByString("=")
			let name = item[0].stringByRemovingPercentEncoding!
			let value = item[1].stringByReplacingOccurrencesOfString("+", withString: " ").stringByRemovingPercentEncoding
			
			data[name] = value
			
		}
		
		return data
		
	}
	
}

func htmlencode(str: String) -> String {
	
	// based on http://stackoverflow.com/a/1673173
	
	return str.stringByReplacingOccurrencesOfString("&", withString: "&amp;")
		.stringByReplacingOccurrencesOfString("\"", withString: "&quot;")
		.stringByReplacingOccurrencesOfString("'", withString: "&#39;")
		.stringByReplacingOccurrencesOfString("<", withString: "&lt;")
		.stringByReplacingOccurrencesOfString(">", withString: "&gt;")
	
}
