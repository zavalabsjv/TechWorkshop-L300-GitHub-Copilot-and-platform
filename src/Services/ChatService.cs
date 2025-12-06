using System.Net.Http.Headers;
using System.Text;
using System.Text.Json;
using Azure.Identity;
using Azure.AI.ContentSafety;
using Azure;

namespace ZavaStorefront.Services
{
    public class ChatService
    {
        private readonly IHttpClientFactory _httpClientFactory;
        private readonly IConfiguration _configuration;
        private readonly ILogger<ChatService> _logger;
        private readonly DefaultAzureCredential _credential;

        public ChatService(IHttpClientFactory httpClientFactory, IConfiguration configuration, ILogger<ChatService> logger)
        {
            _httpClientFactory = httpClientFactory;
            _configuration = configuration;
            _logger = logger;
            // DefaultAzureCredential will use managed identity when running on Azure
            // For local development, it will fall back to other authentication methods
            _credential = new DefaultAzureCredential(new DefaultAzureCredentialOptions
            {
                ExcludeSharedTokenCacheCredential = true
            });
        }

        private async Task<(bool isSafe, string message)> CheckContentSafetyAsync(string userMessage)
        {
            try
            {
                var safetyEndpoint = _configuration["AI_CONTENT_SAFETY_ENDPOINT"];
                var safetyApiKey = _configuration["AI_CONTENT_SAFETY_API_KEY"];

                if (string.IsNullOrEmpty(safetyEndpoint) || string.IsNullOrEmpty(safetyApiKey))
                {
                    _logger.LogWarning("Content Safety not configured, skipping check");
                    return (true, "");
                }

                var client = new ContentSafetyClient(new Uri(safetyEndpoint), new AzureKeyCredential(safetyApiKey));
                var request = new AnalyzeTextOptions(userMessage);

                var response = await client.AnalyzeTextAsync(request);

                _logger.LogInformation("Content Safety Analysis completed");

                var unsafeCategories = response.Value.CategoriesAnalysis.Where(x => x.Severity >= 2).ToList();

                if (unsafeCategories.Any())
                {
                    _logger.LogWarning("Content flagged as unsafe. Categories: {Categories}", string.Join(", ", unsafeCategories.Select(x => x.Category)));
                    return (false, "I appreciate your message, but I'm unable to process it due to content policy restrictions. Please rephrase your question and try again.");
                }

                return (true, "");
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error checking content safety");
                return (true, "");
            }
        }

        public async Task<string> SendMessageToPhiAsync(string userMessage, string? systemPrompt = null)
        {
            try
            {
                var endpoint = _configuration["AI_FOUNDRY_ENDPOINT"];
                var modelName = _configuration["AI_MODEL_NAME"] ?? "Phi4";

                if (string.IsNullOrEmpty(endpoint))
                {
                    _logger.LogError("Missing Foundry configuration: Endpoint is required");
                    return "Configuration error: Missing Foundry endpoint.";
                }

                // Validate endpoint has proper path (either AI Foundry or Azure OpenAI format)
                if (!endpoint.Contains("/chat/completions"))
                {
                    _logger.LogError("Invalid endpoint format: missing /chat/completions path. Endpoint: {Endpoint}", endpoint);
                    return "Configuration error: Endpoint must include /chat/completions path.";
                }

                // Extract the base endpoint (without query string) for token request
                var aiServicesResource = "https://cognitiveservices.azure.com";

                var client = _httpClientFactory.CreateClient();
                
                // Try to use managed identity first (identity-only authentication)
                try
                {
                    _logger.LogInformation("Attempting to use managed identity authentication");
                    var accessToken = await _credential.GetTokenAsync(
                        new Azure.Core.TokenRequestContext(new[] { aiServicesResource + "/.default" }));

                    client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", accessToken.Token);
                    _logger.LogInformation("Successfully acquired token using managed identity");
                }
                catch (Azure.Identity.AuthenticationFailedException ex)
                {
                    // Fallback to API key if managed identity fails
                    var apiKey = _configuration["AI_FOUNDRY_API_KEY"];
                    if (!string.IsNullOrEmpty(apiKey))
                    {
                        _logger.LogWarning(ex, "Managed identity authentication failed, falling back to API key authentication");
                        client.DefaultRequestHeaders.Add("api-key", apiKey);
                    }
                    else
                    {
                        _logger.LogError(ex, "Managed identity authentication failed and no API key available for fallback");
                        return $"Authentication error: {ex.Message}. Neither managed identity nor API key is configured.";
                    }
                }
                
                // Check content safety before processing
                var (isSafe, unsafeMessage) = await CheckContentSafetyAsync(userMessage);
                if (!isSafe)
                {
                    return unsafeMessage;
                }
                
                // Build messages list with optional system prompt
                var messages = new List<object>();
                if (!string.IsNullOrEmpty(systemPrompt))
                {
                    messages.Add(new { role = "system", content = systemPrompt });
                }
                messages.Add(new { role = "user", content = userMessage });
                
                // Prepare the request payload for Azure AI Services
                var payload = new
                {
                    model = modelName,
                    messages = messages.ToArray(),
                    max_tokens = 500,
                    temperature = 0.7
                };

                var jsonContent = new StringContent(
                    JsonSerializer.Serialize(payload),
                    Encoding.UTF8,
                    "application/json");

                _logger.LogInformation("Sending message to Phi4 endpoint");

                var response = await client.PostAsync(endpoint, jsonContent);
                
                if (!response.IsSuccessStatusCode)
                {
                    var errorContent = await response.Content.ReadAsStringAsync();
                    _logger.LogError("Phi4 API error: {StatusCode} - {Content}", response.StatusCode, errorContent);
                    return $"Error from Phi4 endpoint: {response.StatusCode}";
                }

                var responseContent = await response.Content.ReadAsStringAsync();
                
                if (string.IsNullOrWhiteSpace(responseContent))
                {
                    _logger.LogError("Empty response from Phi4 endpoint");
                    return "Empty response from Phi4 endpoint";
                }
                
                var responseJson = JsonDocument.Parse(responseContent);
                
                // Extract the assistant's response from the API response
                var firstChoice = responseJson.RootElement
                    .GetProperty("choices")[0]
                    .GetProperty("message")
                    .GetProperty("content")
                    .GetString();

                _logger.LogInformation("Received response from Phi4");
                return firstChoice ?? "No response from Phi4";
            }
            catch (Azure.Identity.AuthenticationFailedException ex)
            {
                _logger.LogError(ex, "Failed to authenticate with Azure Identity (managed identity or fallback credentials)");
                return $"Authentication error: {ex.Message}. Ensure managed identity is properly configured or API key is set.";
            }
            catch (HttpRequestException ex)
            {
                _logger.LogError(ex, "HTTP request error while calling Phi4 endpoint");
                return $"Network error: {ex.Message}";
            }
            catch (JsonException ex)
            {
                _logger.LogError(ex, "JSON parsing error in Phi4 response");
                return "Error parsing response from Phi4";
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Unexpected error calling Phi4 endpoint");
                return $"Unexpected error: {ex.Message}";
            }
        }
    }
}
