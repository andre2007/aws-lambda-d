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

module aws.lambda_runtime.outcome;

class Outcome(TResult, TFailure) 
{
    this(TResult s) 
    {
        this.s = s;
        this.success = true;
    
    }

    this(TFailure f) 
    {
        this.f = f;
        this.success = false;
    }

    this(Outcome other)
    {
        this.success = other.success;

        if (success) {
            s = other.s;
        }
        else 
        {
            f = other.f;
        }
    }

    TResult getResult()
    {
        assert(success);
        return s;
    }

    TFailure getFailure()
    {
        assert(!success);
        return f;
    }

    bool isSuccess() 
    { 
        return success; 
    }

private:
    union {
        TResult s;
        TFailure f;
    };
    bool success;
};
