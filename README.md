# aws-lambda-d

This is a translation from the C++ library https://github.com/awslabs/aws-lambda-cpp to D.

Use this library to create an executable (See `examples/sample.d`).
Add the executable together with a file `bootstrap`
into a zip archive. Set executable flag for file `bootstrap`. Content of file `bootstrap`:

```bash
#!/bin/sh
cd $LAMBDA_TASK_ROOT
$_HANDLER 
```

