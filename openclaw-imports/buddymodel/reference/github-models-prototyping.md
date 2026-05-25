# Prototyping with AI models

Find and experiment with AI models for free.

If you want to develop a generative AI application, you can use GitHub Models to find and experiment with AI models for free. Once you are ready to bring your application to production, [opt in to paid usage](https://docs.github.com/en/billing/managing-billing-for-your-products/about-billing-for-github-models) for your enterprise.

Organization owners can integrate their preferred custom models into GitHub Models, by using an organization's own LLM API keys. See [Using your own API keys in GitHub Models](https://docs.github.com/en/github-models/github-models-at-scale/set-up-custom-model-integration-models-byok).

See also [Responsible use of GitHub Models](https://docs.github.com/en/github-models/responsible-use-of-github-models).

## Finding AI models

To find an AI model:

1. Go to [github.com/marketplace/models](https://github.com/marketplace/models).
2. Click **Model: Select a Model** at the top left of the page.
3. Choose a model from the dropdown menu.

Alternatively, in the dropdown menu, click **View all models**, click a model in the Marketplace, then click **Playground**.

The model is opened in the model playground. Details of the model are displayed in the sidebar on the right. If the sidebar is not displayed, expand it by clicking the icon at the right of the playground.

> [!NOTE]
> Access to OpenAI's models is in public preview and subject to change.

## Experimenting with AI models in the playground

The AI model playground is a free resource that allows you to adjust model parameters and submit prompts to see how a model responds.

> [!NOTE]
> * The model playground is in public preview and subject to change.
> * The playground is rate limited. See [Rate limits](#rate-limits) below.

To adjust parameters for the model, in the playground, select the **Parameters** tab in the sidebar. To see code that corresponds to the parameters that you selected, switch from the **Chat** tab to the **Code** tab.

### Comparing models

You can submit a prompt to two models at the same time and compare the responses. With one model open in the playground, click **Compare**, then, in the dropdown menu, select a model for comparison.

The selected model opens in a second chat window. When you type a prompt in either chat window, the prompt is mirrored to the other window. The prompts are submitted simultaneously so that you can compare the responses from each model. Any parameters you set are used for both models.

## Evaluating AI models

Once you've started testing prompts in the playground, you can evaluate model performance using structured metrics. Evaluations help you compare multiple prompt configurations across different models and determine which setup performs best.

In the Comparisons view, you can apply evaluators like similarity, relevance, and groundedness to measure how well each output meets your expectations. You can also define your own evaluation criteria with a custom prompt evaluator. For step-by-step instructions, see [Evaluating outputs](https://docs.github.com/en/github-models/use-github-models/evaluating-ai-models#evaluating-outputs).

## Experimenting with AI models using the API

> [!NOTE]
> The free API usage is in public preview and subject to change.

GitHub provides free API usage so that you can experiment with AI models in your own application.

The steps to use each model are similar. In general, you will need to:

1. Go to [github.com/marketplace/models](https://github.com/marketplace/models).
2. Click **Model: Select a Model** at the top left of the page.
3. Choose a model from the dropdown menu.
   Alternatively, in the dropdown menu, click **View all models**, click a model in the Marketplace, then click **Playground**.
4. Click the **Code** tab.
5. Optionally, use the language dropdown to select the programming language.
6. Optionally, use the SDK dropdown to select which SDK to use. All models can be used with the Azure AI Inference SDK, and some models support additional SDKs. If you want to easily switch between models, you should select "Azure AI Inference SDK." If you selected "REST" as the language, you won't use an SDK. Instead, you will use the API endpoint directly. See [GitHub Models REST API](https://docs.github.com/en/rest/models?apiVersion=2022-11-28).
7. Either open a codespace, or set up your local environment:
   - To run in a codespace, click **Run codespace**, then click **Create new codespace**.
   - To run locally:
     - Create a GitHub personal access token. The token needs to have `models:read` permissions. See [Managing your personal access tokens](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/managing-your-personal-access-tokens).
     - Save your token as an environment variable.
     - Install the dependencies for the SDK, if required.
8. Use the example code to make a request to the model.

The free API usage is rate limited. See [Rate limits](#rate-limits) below.

### Code Example

```javascript
import OpenAI from "openai";

const token = process.env["GITHUB_TOKEN"];
const endpoint = "https://models.github.ai/inference";
const model = "openai/gpt-4o"; // Note: gpt-5 may not be available yet

export async function main() {
  const client = new OpenAI({
    baseURL: endpoint,
    apiKey: token,
  });

  const response = await client.chat.completions.create({
    messages: [
      { role: "system", content: "You are a helpful assistant." },
      { role: "user", content: "What is the capital of France?" }
    ],
    model: model
  });

  console.log(response.choices[0].message.content);
}

main().catch((err) => {
  console.error("The sample encountered an error:", err);
});
```

## Saving and sharing your playground experiments

You can save and share your progress in the playground with presets. Presets save:

- Your current state
- Your parameters
- Your chat history (optional)

To create a preset for your current context, select **Preset: PRESET-NAME** at the top right of the playground, then click **Create new preset**.

You need to name your preset, and you can also choose to provide a preset description, include your chat history, and allow your preset to be shared.

There are two ways to load a preset:

- Select the **Preset: PRESET-NAME** dropdown menu, then click the preset you want to load.
- Open a shared preset URL

After you load a preset, you can edit, share, or delete the preset:

- To edit the preset, change the parameters and prompt the model. Once you are satisfied with your changes, select the **Preset: PRESET-NAME** dropdown menu, then click **Edit preset** and save your updates.
- To share the preset, select the **Preset: PRESET-NAME** dropdown menu, then click **Share preset** to get a shareable URL.
- To delete the preset, select the **Preset: PRESET-NAME** dropdown menu, then click **Delete preset** and confirm the deletion.

## Using the prompt editor

The prompt editor in GitHub Models is designed to help you iterate, refine, and perfect your prompts. This dedicated view provides a focused and intuitive experience for crafting and testing inputs, enabling you to:

- Quickly test and refine prompts without the complexity of multi-turn interactions.
- Fine-tune prompts for precision and relevance in your projects.
- Use a specialized space for single-turn scenarios to ensure consistent and optimized results.

To access the prompt editor, click **Prompt editor** at the top right of the playground.

## Experimenting with AI models in Visual Studio Code

> [!NOTE]
> The AI Toolkit extension for Visual Studio Code is in public preview and is subject to change.

If you prefer to experiment with AI models in your IDE, you can install the AI Toolkit extension for Visual Studio Code, then test models with adjustable parameters and context.

1. In Visual Studio Code, install the pre-release version of the [AI Toolkit for Visual Studio Code](https://marketplace.visualstudio.com/items?itemName=ms-windows-ai-studio.windows-ai-studio).
2. To open the extension, click the AI Toolkit icon in the activity bar.
3. Authorize the AI Toolkit to connect to your GitHub account.
4. In the "My models" section of the AI Toolkit panel, click **Open Model Catalog**, then find a model to experiment with.
   - To use a model hosted remotely through GitHub Models, on the model card, click **Try in playground**.
   - To download and use a model locally, on the model card, click **Download**. Once the download is complete, on the same model card, click **Load in playground**.
5. In the sidebar, provide any context instructions and inference parameters for the model, then send a prompt.

## Going to production

The free rate limits provided in the playground and API usage are intended to help you get started with experimentation. When you are ready to move beyond the free offering, you have two options for accessing AI models beyond the free limits:

- You can opt in to paid usage for GitHub Models, allowing your organization to access increased rate limits, larger context windows, and additional features. See [GitHub Models billing](https://docs.github.com/en/billing/managing-billing-for-your-products/about-billing-for-github-models).
- If you have an existing OpenAI or Azure subscription, you can bring your own API keys (BYOK) to access custom models. Billing and usage are managed directly through your provider account, such as your Azure Subscription ID. See [Using your own API keys in GitHub Models](https://docs.github.com/en/github-models/github-models-at-scale/set-up-custom-model-integration-models-byok).

## Rate limits

> [!NOTE]
> Once you opt in to paid usage, you will have access to production grade rate limits and be billed for all usage thereafter. For more information about these rate limits, see [Microsoft Foundry Models quotas and limits](https://learn.microsoft.com/en-us/azure/ai-foundry/model-inference/quotas-limits) in the Azure documentation.

The playground and free API usage are rate limited by requests per minute, requests per day, tokens per request, and concurrent requests. If you get rate limited, you will need to wait for the rate limit that you hit to reset before you can make more requests.

Low, high, and embedding models have different rate limits. To see which type of model you are using, refer to the model's information in GitHub Marketplace.

For custom models accessed with your own API keys, rate limits are set and enforced by your model provider.

### Rate Limit Table

| Rate limit tier | Rate limits | Copilot Free | Copilot Pro | Copilot Business | Copilot Enterprise |
|----------------|-------------|--------------|-------------|------------------|-------------------|
| **Low** | Requests per minute | 15 | 15 | 15 | 20 |
| | Requests per day | 150 | 150 | 300 | 450 |
| | Tokens per request | 8000 in, 4000 out | 8000 in, 4000 out | 8000 in, 4000 out | 8000 in, 8000 out |
| | Concurrent requests | 5 | 5 | 5 | 8 |
| **High** | Requests per minute | 10 | 10 | 10 | 15 |
| | Requests per day | 50 | 50 | 100 | 150 |
| | Tokens per request | 8000 in, 4000 out | 8000 in, 4000 out | 8000 in, 4000 out | 16000 in, 8000 out |
| | Concurrent requests | 2 | 2 | 2 | 4 |
| **Embedding** | Requests per minute | 15 | 15 | 15 | 20 |
| | Requests per day | 150 | 150 | 300 | 450 |
| | Tokens per request | 64000 | 64000 | 64000 | 64000 |
| | Concurrent requests | 5 | 5 | 5 | 8 |
| **Azure OpenAI o1, o3, and gpt-5** | Requests per minute | N/A | 1 | 2 | 2 |
| | Requests per day | N/A | 8 | 10 | 12 |
| | Tokens per request | N/A | 4000 in, 4000 out | 4000 in, 4000 out | 4000 in, 8000 out |
| | Concurrent requests | N/A | 1 | 1 | 1 |

**Important:** These limits are subject to change without notice.

### Error: 413 Request body too large

If you encounter `413 Request body too large` error for gpt-5 model:
- Max input tokens: 4000
- Max output tokens: 4000
- Solution: Reduce your prompt size or split into multiple requests

## Leaving feedback

To ask questions and share feedback, see this [GitHub Models discussion post](https://github.com/orgs/community/discussions/159087).

To learn how others are using GitHub Models, visit the [GitHub Community discussions for Models](https://github.com/orgs/community/discussions/categories/models).
