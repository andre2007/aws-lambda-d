/*
 * Copyright 2018-present Amazon.com, Inc. or its affiliates. All Rights Reserved.
 *
 * Licensed under the Apache License, Version 2.0 (the "License").
 * You may not use this file except in compliance with the License.
 * A copy of the License is located at
 *
 *  http://aws.amazon.com/apache2.0
 *
 * or in the "license" file accompanying this file. This file is distributed
 * on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either
 * express or implied. See the License for the specific language governing
 * permissions and limitations under the License.
 */

///
module aws.lambda_runtime.runtime;

import core.time : seconds;
import std.datetime.systime : SysTime, Clock;
import std.process : environment;
import std.conv : to;
import std.net.curl;
import std.typecons : No;
import etc.c.curl : curl_easy_strerror, curl_version;

import aws.http.response;
import aws.logging.logging;
import aws.lambda_runtime.outcome;
import aws.lambda_runtime.version_;

/// Entry method
void runHandler(InvocationResponse function(InvocationRequest) handler)
{
    logInfo(LOG_TAG, "Initializing the D Lambda Runtime version %s", getVersion());
    string endpoint = "http://";
    string endpointHost = environment.get("AWS_LAMBDA_RUNTIME_API", "");
    assert(endpointHost != "", "LAMBDA_SERVER_ADDRESS not defined");
    logDebug(LOG_TAG, "LAMBDA_SERVER_ADDRESS defined in environment as: %s", endpointHost);
    endpoint ~= endpointHost;

    Runtime rt = new Runtime(endpoint);
    size_t retries = 0;
    size_t maxRetries = 3;

    while (retries < maxRetries) {
        auto nextOutcome = rt.getNext();
        if (!nextOutcome.isSuccess()) {
            if (nextOutcome.getFailure() == ResponseCode.REQUEST_NOT_MADE)
            {
                ++retries;
                continue;
            }

            logInfo(LOG_TAG, "HTTP request was not successful. HTTP response code: %d. Retrying..", nextOutcome.getFailure());
            ++retries;
            continue;
        }

        retries = 0;
        auto req = nextOutcome.getResult();
        logInfo(LOG_TAG, "Invoking user handler");
        InvocationResponse res = handler(req);
        logInfo(LOG_TAG, "Invoking user handler completed.");

        if (res.isSuccess()) {
            auto postOutcome = rt.postSuccess(req.requestId, res);
            if (!handlePostOutcome(postOutcome, req.requestId)) 
            {
                return; // TODO: implement a better retry strategy
            }
        }
        else {
            auto postOutcome = rt.postFailure(req.requestId, res);
            if (!handlePostOutcome(postOutcome, req.requestId))
            {
                return; // TODO: implement a better retry strategy
            }
        }
    }

    if (retries == maxRetries)
    {
        string libCurlVersion = to!string(curl_version());
        logError(LOG_TAG, "Exhausted all retries. This is probably a bug in libcurl v" ~ libCurlVersion ~ " Exiting!");
    }
}

///
struct InvocationRequest 
{
    /// The user's payload represented as a UTF-8 string.
    string payload;

    /// An identifier unique to the current invocation.
    string requestId;

    /// X-Ray tracing ID of the current invocation.
    string xrayTraceId;

    /// Information about the client application and device when invoked through the AWS Mobile SDK.
    string clientContext;
    
    /// Information about the Amazon Cognito identity provider when invoked through the AWS Mobile SDK.
    string cognitoIdentity;

    /// The ARN requested. This can be different in each invoke that executes the same version.
    string functionArn;

    /// Function execution deadline counted in milliseconds since the Unix epoch.
    SysTime deadline;

    /// The number of milliseconds left before lambda terminates the current execution.
    long getTimeRemaining() 
    {
        return (deadline - Clock.currTime()).total!"msecs";
    }
}

///
class InvocationResponse 
{
    /// Create a successful invocation response with the given payload and content-type.
    static InvocationResponse success(string payload, string contentType)
    {
        InvocationResponse r = new InvocationResponse();
        r._success = true;
        r._contentType = contentType;
        r._payload = payload;
        return r;
    }

    /**
     * Create a failure response with the given error message and error type.
     * The content-type is always set to application/json in this case.
     */
    static InvocationResponse failure(string errorMessage, string errorType)
    {
        import std.json;
        
        InvocationResponse r = new InvocationResponse();
        r._success = false;
        r._contentType = "application/json";
        JSONValue jsPayload = JSONValue(["errorMessage": JSONValue(errorMessage), "errorType":  JSONValue(errorType), "stackTrace": JSONValue(string[].init)]);
        r._payload = jsPayload.toString();
        return r;
    }

    /// Get the MIME type of the payload.
    string getContentType() 
    { 
        return _contentType; 
    }

    /// Get the payload string. The string is assumed to be UTF-8 encoded.
    string getPayload() 
    { 
        return _payload; 
    }

    /// Returns true if the payload and content-type are set. Returns false if the error message and error types are set.
    bool isSuccess() 
    { 
        return _success; 
    }
private:
    // The output of the function which is sent to the lambda caller.
    string _payload;

    // The MIME type of the payload. This is always set to 'application/json' in unsuccessful invocations.
    string _contentType;

    // Flag to distinguish if the contents are for successful or unsuccessful invocations.
    bool _success;
}

private:

enum LOG_TAG = "LAMBDA_RUNTIME";
enum REQUEST_ID_HEADER = "lambda-runtime-aws-request-id";
enum TRACE_ID_HEADER = "lambda-runtime-trace-id";
enum CLIENT_CONTEXT_HEADER = "lambda-runtime-client-context";
enum COGNITO_IDENTITY_HEADER = "lambda-runtime-cognito-identity";
enum DEADLINE_MS_HEADER = "lambda-runtime-deadline-ms";
enum FUNCTION_ARN_HEADER = "lambda-runtime-invoked-function-arn";

enum Endpoints
{
    INIT,
    NEXT,
    RESULT,
}

bool isSuccess(ResponseCode httpcode)
{
    return httpcode >= 200 && httpcode <= 299;
}

void setUserAgentHeader(HTTP http)
{
    static string userAgent = "AWS_Lambda_D/" ~ getVersion();
    http.setUserAgent(userAgent);
}

enum CURLE_OK = 0;

class Runtime
{   
    alias NextOutcome = Outcome!(InvocationRequest, ResponseCode);
    alias PostOutcome = Outcome!(NoResult, ResponseCode);

    private string[] _endpoints;
    
    this(string endpoint)
    {        
        _endpoints = [
            endpoint ~ "/2018-06-01/runtime/init/error",
            endpoint ~ "/2018-06-01/runtime/invocation/next",
            endpoint ~ "/2018-06-01/runtime/invocation/"
        ];
    }
    
    // Ask lambda for an invocation.
    NextOutcome getNext()
    {
        Response resp = new Response();
        
        auto http = HTTP(_endpoints[Endpoints.NEXT]);
        http.method = HTTP.Method.get;
        setUserAgentHeader(http);

        // lambda freezes the container when no further tasks are available. The freezing period could be longer than the
        // request timeout, which causes the following get_next request to fail with a timeout error.
        http.operationTimeout = 0.seconds;
        http.connectTimeout = 1.seconds;
        // curl_easy_setopt(m_curl_handle, CURLOPT_NOSIGNAL, 1L);
        http.tcpNoDelay = true;
        //curl_easy_setopt(m_curl_handle, CURLOPT_HTTP_VERSION, CURL_HTTP_VERSION_1_1);

        version(CURL_DEBUG)
        {
            http.verbose = true;
        }

        http.onReceiveHeader = (in char[] key, in char[] value) { 
            resp.addHeader(key.idup, value.idup); 
        };
        
        http.onReceive = (ubyte[] data) {
            resp.appendBody(cast(string)data);
            return data.length;
        };
        
        logDebug(LOG_TAG, "Making request to %s", _endpoints[Endpoints.NEXT]);
        
        auto curlCode = http.perform(No.throwOnError);
        
        if (curlCode != CURLE_OK)
        {
            string errorText = to!string(curl_easy_strerror(curlCode));
            
            logDebug(LOG_TAG, "CURL returned error code %d - %s", curlCode, errorText);
            logError(LOG_TAG, "Failed to get next invocation. No Response from endpoint");
            return new NextOutcome(ResponseCode.REQUEST_NOT_MADE);
        }
        
        logDebug(LOG_TAG, "Completed request to %s", _endpoints[Endpoints.NEXT]);
        resp.setResponseCode(cast(ResponseCode) http.statusLine.code); 

        if (!isSuccess(resp.getResponseCode()))
        {
            logError(LOG_TAG, "Failed to get next invocation. Http Response code: %d", resp.getResponseCode());
            return new NextOutcome(resp.getResponseCode());
        }

        if (!resp.hasHeader(REQUEST_ID_HEADER))
        {
            logError(LOG_TAG, "Failed to find header %s in response", REQUEST_ID_HEADER);
            return new NextOutcome(ResponseCode.REQUEST_NOT_MADE);
        }
        
        InvocationRequest req;
        req.payload = resp.getBody();
        req.requestId = resp.getHeader(REQUEST_ID_HEADER);

        if (resp.hasHeader(TRACE_ID_HEADER))
        {
            req.xrayTraceId = resp.getHeader(TRACE_ID_HEADER);
        }

        if (resp.hasHeader(CLIENT_CONTEXT_HEADER))
        {
            req.clientContext = resp.getHeader(CLIENT_CONTEXT_HEADER);
        }

        if (resp.hasHeader(COGNITO_IDENTITY_HEADER))
        {
            req.cognitoIdentity = resp.getHeader(COGNITO_IDENTITY_HEADER);
        }

        if (resp.hasHeader(FUNCTION_ARN_HEADER))
        {
            req.functionArn = resp.getHeader(FUNCTION_ARN_HEADER);
        }

        if (resp.hasHeader(DEADLINE_MS_HEADER))
        {
            import core.time : msecs;
            
            string deadlineString = resp.getHeader(DEADLINE_MS_HEADER);
            ulong ms = to!ulong(deadlineString[0..10]);
            assert(ms > 0 && ms < ulong.max);
            req.deadline = SysTime.fromUnixTime(ms);
            req.deadline.fracSecs = msecs(deadlineString[10..$].to!long);
            
            logInfo(LOG_TAG, "Received payload: %s\nTime remaining: %s", req.payload, req.getTimeRemaining());
        }
        return new NextOutcome(req);
    }
    
    /// Tells lambda that the function has succeeded.
    PostOutcome postSuccess(string requestId, InvocationResponse handlerResponse)
    {
        string url = _endpoints[Endpoints.RESULT] ~ requestId ~ "/response";
        return doPost(url, requestId, handlerResponse);
    }

    /// Tells lambda that the function has failed.
    PostOutcome postFailure(string requestId, InvocationResponse handlerResponse)
    {
        string url = _endpoints[Endpoints.RESULT] ~ requestId ~ "/error";
        return doPost(url, requestId, handlerResponse);
    }
    
    private PostOutcome doPost(string url, string requestId, InvocationResponse handlerResponse)
    {
        auto http = HTTP(url);
        http.method = HTTP.Method.post;
        setUserAgentHeader(http);
        http.operationTimeout = 0.seconds;
        http.connectTimeout = 1.seconds;
        // curl_easy_setopt(m_curl_handle, CURLOPT_NOSIGNAL, 1L);
        http.tcpNoDelay = true;
        //curl_easy_setopt(m_curl_handle, CURLOPT_HTTP_VERSION, CURL_HTTP_VERSION_1_1);

        version(CURL_DEBUG)
        {
            http.verbose = true;
        }
        
        logInfo(LOG_TAG, "Making request to %s", url);
        string contentType = (handlerResponse.getContentType())
            ? handlerResponse.getContentType : "text/html"; 
        http.addRequestHeader("expect", "");
        http.addRequestHeader("transfer-encoding", "");
        string payload = handlerResponse.getPayload();
        http.setPostData(payload, contentType);
        http.contentLength = payload.length;
       
        logDebug(LOG_TAG, "calculating content length... %s", ("content-length: " ~ to!string(payload.length)));
        
        Response resp = new Response();
        auto curlCode = http.perform(No.throwOnError);

        if (curlCode != CURLE_OK) {
            string errorText = to!string(curl_easy_strerror(curlCode));
            
            logDebug(LOG_TAG, "CURL returned error code %d - %s, for invocation %s", curlCode,
                errorText,
                requestId);
            return new PostOutcome(ResponseCode.REQUEST_NOT_MADE);
        }

        if (!isSuccess(cast(ResponseCode) http.statusLine.code)) {
            logError(LOG_TAG, "Failed to post handler success response. Http response code: %ld.", http.statusLine.code);
            return new PostOutcome(cast (ResponseCode) http.statusLine.code);
        }
        return new PostOutcome(NoResult());
    }    
}

bool handlePostOutcome(Runtime.PostOutcome o, string requestId)
{
    if (o.isSuccess())
    {
        return true;
    }

    if (o.getFailure() == ResponseCode.REQUEST_NOT_MADE)
    {
        logError(LOG_TAG, "Failed to send HTTP request for invocation %s.", requestId);
        return false;
    }

    logInfo(LOG_TAG, "HTTP Request for invocation %s was not successful. HTTP response code: %d.", requestId, o.getFailure());
    return false;
}

struct NoResult {}

