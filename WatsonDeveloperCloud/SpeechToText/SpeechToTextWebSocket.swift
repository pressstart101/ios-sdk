/**
 * Copyright IBM Corporation 2015
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 **/

import Foundation

/** Abstracts the WebSockets connection to the Watson Speech to Text service. */
class SpeechToTextWebSocket {

    private let socket: WatsonWebSocket
    private var results: [SpeechToTextResult]
    private let failure: (NSError -> Void)?
    private let success: [SpeechToTextResult] -> Void

    /**
     Create a `SpeechToTextWebSocket` object to communicate with Speech to Text.

     - parameter authStrategy: An `AuthenticationStrategy` that defines how to authenticate
        with the Watson Developer Cloud's Speech to Text service. The `AuthenticationStrategy`
        is used internally to obtain tokens, refresh expired tokens, and maintain information
        about authentication state.
     - parameter settings: The configuration for this transcription request.
     - parameter failure: A function executed whenever an error occurs.
     - parameter success: A function executed with all transcription results whenever
        a final or interim transcription is received.

     - returns: A `SpeechToTextWebSocket` object that can communicate with Speech to Text.
     */
    init?(
        authStrategy: AuthenticationStrategy,
        settings: SpeechToTextSettings,
        failure: (NSError -> Void)? = nil,
        success: [SpeechToTextResult] -> Void)
    {
        guard let url = SpeechToTextConstants.websocketsURL(settings) else {
            // A bug in the Swift compiler requires us to set all properties before returning nil
            // This bug is fixed in Swift 2.2, so we can remove this code when Xcode is updated
            self.socket = WatsonWebSocket(authStrategy: authStrategy,
                url: NSURL(string: "http://www.ibm.com")!)
            self.results = []
            self.failure = nil
            self.success = {result in }
            return nil
        }

        self.socket = WatsonWebSocket(authStrategy: authStrategy, url: url)
        self.results = [SpeechToTextResult]()
        self.failure = failure
        self.success = success

        socket.onText = onText
        socket.onData = onData
        socket.onError = onSocketError
    }

    // MARK: WatsonWebSocket API Functions

    /**
     Send data to Speech to Text.
    
     - parameter data: The data to send.
    */
    func writeData(data: NSData) {
        socket.writeData(data)
    }

    /**
     Send text to Speech to Text.

     - parameter str: The text string to send.
     */
    func writeString(str: String) {
        socket.writeString(str)
    }

    /**
     Send a ping to Speech to Text.

     - parameter data: The data to send.
     */
    func writePing(data: NSData) {
        socket.writePing(data)
    }

    /**
     Disconnect from Speech to Text.

     - parameter forceTimeout: The time to wait for a graceful disconnect before forcing the
        connection to close.
     */
    func disconnect(forceTimeout: NSTimeInterval? = nil) {
        socket.disconnect(forceTimeout)
    }

    // MARK: WatsonWebSocket Delegate Functions

    /**
     Process a text payload from Speech to Text.

     - parameter text: The text payload from Speech to Text.
     */
    private func onText(text: String) {
        guard let response = SpeechToTextGenericResponse.parseResponse(text) else {
            let description = "Could not serialize a generic text response to an object."
            let error = createError(SpeechToTextConstants.domain, description: description)
            failure?(error)
            return
        }

        switch response {
        case .State(let state): onState(state)
        case .Results(let wrapper): onResults(wrapper)
        case .Error(let error): onServiceError(error)
        }
    }

    /**
     Process a data payload from Speech to Text.
    
     - parameter data: The data payload from Speech to Text.
     */
    private func onData(data: NSData) {
        return
    }

    /**
     Handle a socket error generated by the connection to Speech to Text.

     - parameter error: The error that occurred.
     */
    private func onSocketError(error: NSError) {
        failure?(error)
    }

    // MARK: Helper Functions: Parse Generic Response

    /**
     Handle a state message from Speech to Text.

     - parameter state: The state of the Speech to Text recognition request.
     */
    private func onState(state: SpeechToTextState) {
        return
    }

    /**
     Handle transcription results from Speech to Text.

     - parameter wrapper: A `SpeechToTextResultWrapper` that encapsulates the new or updated
        transcriptions along with state information to update the internal `results` array.
     */
    private func onResults(wrapper: SpeechToTextResultWrapper) {
        updateResultsArray(wrapper)
        success(results)
    }

    /**
     Update the `results` array with new or updated transcription results from Speech to Text.

     - parameter wrapper: A `SpeechToTextResultWrapper` that encapsulates the new or updated
        transcriptions along with state information to update the internal `results` array.
     */
    private func updateResultsArray(wrapper: SpeechToTextResultWrapper) {
        var localIndex = wrapper.resultIndex
        var wrapperIndex = 0
        while localIndex < results.count {
            results[localIndex] = wrapper.results[wrapperIndex]
            localIndex = localIndex + 1
            wrapperIndex = wrapperIndex + 1
        }
        while wrapperIndex < wrapper.results.count {
            results.append(wrapper.results[wrapperIndex])
            wrapperIndex = wrapperIndex + 1
        }
    }

    /*
     Handle an error generated by Speech to Text.

     - parameter error: The error that occurred.
     */
    private func onServiceError(error: SpeechToTextError) {
        let error = createError(SpeechToTextConstants.domain, description: error.error)
        failure?(error)
    }
}
