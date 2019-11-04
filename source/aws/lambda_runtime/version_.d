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
module aws.lambda_runtime.version_;

/// Returns the major component of the library version.
uint get_version_major()
{
    return 0;
}

/// Returns the minor component of the library version.
uint get_version_minor()
{
    return 1;
}

/// Returns the patch component of the library version.
uint get_version_patch()
{
    return 0;
}

/// Returns the semantic version of the library in the form Major.Minor.Patch
string getVersion()
{
    import std.conv : text;
    
    return get_version_major().text ~ "." ~ get_version_minor().text ~ "." ~ get_version_patch().text;
}

