using System;
using System.IO;
using NJsonSchema;

namespace JsonValidator
{
    class Program
    {
        static int Main(string[] args)
        {
            if (args.Length < 2)
            {
                Console.Error.WriteLine("Usage: JsonValidator <schemaPath> <jsonPath> [failOnError]");
                return 1;
            }

            string schemaPath = args[0];
            string jsonPath = args[1];
            bool failOnError = args.Length > 2 && args[2].Equals("true", StringComparison.OrdinalIgnoreCase);

            if (!File.Exists(schemaPath))
            {
                Console.Error.WriteLine("Schema file not found: " + schemaPath);
                return 1;
            }

            if (!File.Exists(jsonPath))
            {
                Console.Error.WriteLine("JSON file not found: " + jsonPath);
                return 1;
            }

            try
            {
                string schemaJson = File.ReadAllText(schemaPath);
                string instanceJson = File.ReadAllText(jsonPath);

                var schema = JsonSchema.FromJson(schemaJson);
                var errors = schema.Validate(instanceJson);

                if (errors.Count == 0)
                {
                    Console.WriteLine("Validation PASSED");
                    return 0;
                }
                else
                {
                    Console.Error.WriteLine("Validation FAILED with " + errors.Count + " error(s):");
                    foreach (var err in errors)
                    {
                        string path = err.Path ?? "root";
                        string msg = err.Kind != null ? err.Kind + ": " + err.ErrorMessage : err.ErrorMessage;
                        Console.Error.WriteLine("  [" + path + "] " + msg);
                    }
                    return failOnError ? 1 : 0;
                }
            }
            catch (Exception ex)
            {
                Console.Error.WriteLine("Validation failed with exception: " + ex.Message);
                return 1;
            }
        }
    }
}