using System;
using System.IO;
using System.Text.Json;
using NJsonSchema;

namespace JsonValidator
{
    class Program
    {
        static int Main(string[] args)
        {
            string schemaPath = null;
            string jsonPath = null;
            bool failOnError = false;

            for (int i = 0; i < args.Length; i++)
            {
                switch (args[i])
                {
                    case "-SchemaPath":
                        if (i + 1 < args.Length) schemaPath = args[++i];
                        break;
                    case "-JsonPath":
                        if (i + 1 < args.Length) jsonPath = args[++i];
                        break;
                    case "-FailOnError":
                        failOnError = true;
                        break;
                }
            }

            if (string.IsNullOrEmpty(schemaPath) || string.IsNullOrEmpty(jsonPath))
            {
                Console.Error.WriteLine("Usage: JsonValidator -SchemaPath <schema.json> -JsonPath <data.json> [-FailOnError]");
                return 2;
            }

            try
            {
                var schemaJson = File.ReadAllText(schemaPath);
                var dataJson = File.ReadAllText(jsonPath);

                var schema = JsonSchema.FromJsonAsync(schemaJson).GetAwaiter().GetResult();
                var data = JsonDocument.Parse(dataJson).RootElement;

                var errors = schema.Validate(data.GetRawText());
                
                if (errors.Count > 0)
                {
                    foreach (var error in errors)
                    {
                        Console.Error.WriteLine($"Validation Error: {error.Path} - {error.Kind} - {error}");
                    }
                    return failOnError ? 1 : 0;
                }

                return 0;
            }
            catch (Exception ex)
            {
                Console.Error.WriteLine($"Error: {ex.Message}");
                return 1;
            }
        }
    }
}