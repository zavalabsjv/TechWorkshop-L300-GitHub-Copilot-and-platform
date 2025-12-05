using System.Net.Http.Headers;
using System.Text;
using System.Text.Json;
using Azure.Identity;

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

                // Validate endpoint has proper path
                if (!endpoint.Contains("/models/chat/completions"))
                {
                    _logger.LogError("Invalid endpoint format: missing /models/chat/completions path. Endpoint: {Endpoint}", endpoint);
                    return "Configuration error: Endpoint must include /models/chat/completions path.";
                }

                // Extract the base endpoint (without query string) for token request
                var aiServicesResource = "https://cognitiveservices.azure.com";

                // Get access token using managed identity
                var accessToken = await _credential.GetTokenAsync(
                    new Azure.Core.TokenRequestContext(new[] { aiServicesResource + "/.default" }));

                var client = _httpClientFactory.CreateClient();
                
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

                // Add authorization header with access token from managed identity
                client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", accessToken.Token);

                _logger.LogInformation("Sending message to Phi4 endpoint using managed identity authentication");

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
                return $"Authentication error: {ex.Message}. Ensure managed identity is properly configured.";
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
