/+ dub.sdl:
	name "sample"
	dependency "aws-lambda-d" path="../"
+/

import std;
import aws.lambda_runtime.runtime;

InvocationResponse handler(InvocationRequest request)
{
	return InvocationResponse.success("{\"data\": \"hello world!\"}", "application/json");
}

int main()
{
	runHandler(&handler);
	return 0;
}
