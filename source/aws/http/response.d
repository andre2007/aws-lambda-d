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

module aws.http.response;

import std.string : toLower;

class Response 
{
    // lower-case the name but store the value as is
    void addHeader(string name, string value)
    {
        _headers[name.toLower] = value;
    }
    
    void appendBody(string value)
    {
        _body ~= value;
    }
    
    bool hasHeader(string name)
    {
        return (name.toLower in _headers) !is null;
    }
    
    string getHeader(string name)
    {
        auto p = name.toLower in _headers;
        assert(p !is null);
        return *p;
    }
    
    ResponseCode getResponseCode() 
    { 
        return _responseCode; 
    }
        
    void setResponseCode(ResponseCode c)
    {
        _responseCode = c;
    }
    
    string getContentTpe()
    {
        return _headers.get("content-type", "");
    }
    
    string getBody()
    {
        return _body;
    }

private:
    ResponseCode _responseCode;
    string[string] _headers;
    string _body;
    string _contentType;
};

enum ResponseCode 
{
    REQUEST_NOT_MADE = -1,
    CONTINUE = 100,
    SWITCHING_PROTOCOLS = 101,
    PROCESSING = 102,
    OK = 200,
    CREATED = 201,
    ACCEPTED = 202,
    NON_AUTHORITATIVE_INFORMATION = 203,
    NO_CONTENT = 204,
    RESET_CONTENT = 205,
    PARTIAL_CONTENT = 206,
    MULTI_STATUS = 207,
    ALREADY_REPORTED = 208,
    IM_USED = 226,
    MULTIPLE_CHOICES = 300,
    MOVED_PERMANENTLY = 301,
    FOUND = 302,
    SEE_OTHER = 303,
    NOT_MODIFIED = 304,
    USE_PROXY = 305,
    SWITCH_PROXY = 306,
    TEMPORARY_REDIRECT = 307,
    PERMANENT_REDIRECT = 308,
    BAD_REQUEST = 400,
    UNAUTHORIZED = 401,
    PAYMENT_REQUIRED = 402,
    FORBIDDEN = 403,
    NOT_FOUND = 404,
    METHOD_NOT_ALLOWED = 405,
    NOT_ACCEPTABLE = 406,
    PROXY_AUTHENTICATION_REQUIRED = 407,
    REQUEST_TIMEOUT = 408,
    CONFLICT = 409,
    GONE = 410,
    LENGTH_REQUIRED = 411,
    PRECONDITION_FAILED = 412,
    REQUEST_ENTITY_TOO_LARGE = 413,
    REQUEST_URI_TOO_LONG = 414,
    UNSUPPORTED_MEDIA_TYPE = 415,
    REQUESTED_RANGE_NOT_SATISFIABLE = 416,
    EXPECTATION_FAILED = 417,
    IM_A_TEAPOT = 418,
    AUTHENTICATION_TIMEOUT = 419,
    METHOD_FAILURE = 420,
    UNPROC_ENTITY = 422,
    LOCKED = 423,
    FAILED_DEPENDENCY = 424,
    UPGRADE_REQUIRED = 426,
    PRECONDITION_REQUIRED = 427,
    TOO_MANY_REQUESTS = 429,
    REQUEST_HEADER_FIELDS_TOO_LARGE = 431,
    LOGIN_TIMEOUT = 440,
    NO_RESPONSE = 444,
    RETRY_WITH = 449,
    BLOCKED = 450,
    REDIRECT = 451,
    REQUEST_HEADER_TOO_LARGE = 494,
    CERT_ERROR = 495,
    NO_CERT = 496,
    HTTP_TO_HTTPS = 497,
    CLIENT_CLOSED_TO_REQUEST = 499,
    INTERNAL_SERVER_ERROR = 500,
    NOT_IMPLEMENTED = 501,
    BAD_GATEWAY = 502,
    SERVICE_UNAVAILABLE = 503,
    GATEWAY_TIMEOUT = 504,
    HTTP_VERSION_NOT_SUPPORTED = 505,
    VARIANT_ALSO_NEGOTIATES = 506,
    INSUFFICIENT_STORAGE = 506,
    LOOP_DETECTED = 508,
    BANDWIDTH_LIMIT_EXCEEDED = 509,
    NOT_EXTENDED = 510,
    NETWORK_AUTHENTICATION_REQUIRED = 511,
    NETWORK_READ_TIMEOUT = 598,
    NETWORK_CONNECT_TIMEOUT = 599
}
