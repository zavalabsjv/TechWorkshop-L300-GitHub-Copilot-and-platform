using Microsoft.AspNetCore.Mvc;
using ZavaStorefront.Models;
using ZavaStorefront.Services;

namespace ZavaStorefront.Controllers;

public class ChatController : Controller
{
    private readonly ChatService _chatService;
    private readonly ProductService _productService;
    private readonly ILogger<ChatController> _logger;

    public ChatController(ChatService chatService, ProductService productService, ILogger<ChatController> logger)
    {
        _chatService = chatService;
        _productService = productService;
        _logger = logger;
    }

    public IActionResult Index()
    {
        _logger.LogInformation("Loading chat page");
        return View();
    }

    [HttpPost]
    public async Task<IActionResult> SendMessage(string message)
    {
        if (string.IsNullOrWhiteSpace(message))
        {
            return BadRequest("Message cannot be empty");
        }

        _logger.LogInformation("Processing chat message");

        try
        {
            // Get products to provide context to Phi4
            var products = _productService.GetAllProducts();
            var productContext = FormatProductsForContext(products);
            
            var systemPrompt = $@"You are a helpful shopping assistant for ZavaStorefront. 
You have access to the following products available on the site:

{productContext}

Answer customer questions about these products accurately and helpfully. 
If asked about products not in the list, let them know we don't currently carry them.";

            var response = await _chatService.SendMessageToPhiAsync(message, systemPrompt);
            return Json(new { success = true, response });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error processing chat message");
            return Json(new { success = false, error = ex.Message });
        }
    }

    private static string FormatProductsForContext(List<Product> products)
    {
        var productList = string.Join("\n", products.Select(p => 
            $"- {p.Name}: {p.Description} (${p.Price})"));
        return productList;
    }
}