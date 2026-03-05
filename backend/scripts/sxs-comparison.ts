/**
 * Side-by-Side Translation API Comparison Script
 *
 * Compares Google Cloud Translation, DeepL, and iTranslate APIs
 *
 * Usage:
 *   npx ts-node scripts/sxs-comparison.ts
 *
 * Required environment variables:
 *   - GOOGLE_CLOUD_PROJECT: GCP project ID (uses ADC for auth)
 *   - DEEPL_API_KEY: DeepL API key
 *   - ITRANSLATE_API_KEY: iTranslate API key
 */

// Set dummy Supabase env vars to avoid config validation errors
// (not needed for comparison script)
process.env['SUPABASE_URL'] = process.env['SUPABASE_URL'] || 'https://dummy.supabase.co';
process.env['SUPABASE_SERVICE_KEY'] = process.env['SUPABASE_SERVICE_KEY'] || 'dummy-key';

import {
  GoogleTranslationProvider,
  DeepLTranslationProvider,
  ITranslateProvider,
  TranslationProvider,
} from '../src/services/providers';

// Test sentences covering different scenarios
const TEST_CASES = [
  // Basic greetings
  { text: 'Hello, how are you?', source: 'en', target: 'es', category: 'greeting' },
  { text: 'Good morning!', source: 'en', target: 'fr', category: 'greeting' },

  // Common phrases
  { text: 'Where is the nearest restaurant?', source: 'en', target: 'de', category: 'travel' },
  { text: 'How much does this cost?', source: 'en', target: 'ja', category: 'travel' },
  { text: 'I would like to book a room for two nights.', source: 'en', target: 'it', category: 'travel' },

  // Complex sentences
  { text: 'The weather forecast suggests it might rain tomorrow, so you should bring an umbrella.', source: 'en', target: 'es', category: 'complex' },
  { text: 'Despite the economic challenges, the company managed to increase its revenue by 15% this quarter.', source: 'en', target: 'de', category: 'complex' },

  // Idiomatic expressions
  { text: "It's raining cats and dogs.", source: 'en', target: 'fr', category: 'idiom' },
  { text: 'Break a leg!', source: 'en', target: 'es', category: 'idiom' },
  { text: "Don't put all your eggs in one basket.", source: 'en', target: 'de', category: 'idiom' },

  // Technical content
  { text: 'The API returns a JSON response with the translated text.', source: 'en', target: 'ja', category: 'technical' },
  { text: 'Machine learning models require large datasets for training.', source: 'en', target: 'zh', category: 'technical' },

  // Formal/polite speech
  { text: 'I would be grateful if you could assist me with this matter.', source: 'en', target: 'ja', category: 'formal' },
  { text: 'Please accept my sincere apologies for the inconvenience.', source: 'en', target: 'de', category: 'formal' },

  // Casual speech
  { text: "Hey, what's up? Wanna grab some coffee?", source: 'en', target: 'es', category: 'casual' },
  { text: "That movie was totally awesome, you gotta see it!", source: 'en', target: 'fr', category: 'casual' },

  // Numbers and dates
  { text: 'The meeting is scheduled for January 15th, 2025 at 3:30 PM.', source: 'en', target: 'de', category: 'datetime' },
  { text: 'The price is $49.99, but with the 20% discount, it becomes $39.99.', source: 'en', target: 'ja', category: 'numbers' },

  // Questions
  { text: 'Could you please tell me where the train station is?', source: 'en', target: 'it', category: 'question' },
  { text: 'What time does the museum close today?', source: 'en', target: 'es', category: 'question' },
];

interface ComparisonResult {
  testCase: typeof TEST_CASES[0];
  results: {
    provider: string;
    translation: string;
    latencyMs: number;
    error?: string;
  }[];
}

async function runComparison(): Promise<void> {
  console.log('='.repeat(80));
  console.log('Translation API Side-by-Side Comparison');
  console.log('='.repeat(80));
  console.log();

  // Initialize providers
  const providers: TranslationProvider[] = [];

  // Google Cloud Translation (uses Application Default Credentials)
  if (process.env['GOOGLE_CLOUD_PROJECT']) {
    try {
      providers.push(new GoogleTranslationProvider());
      console.log('✓ Google Cloud Translation: Initialized');
    } catch (e: any) {
      console.log(`✗ Google Cloud Translation: ${e.message}`);
    }
  } else {
    console.log('✗ Google Cloud Translation: Missing GOOGLE_CLOUD_PROJECT');
  }

  // DeepL
  const deeplApiKey = process.env['DEEPL_API_KEY'];
  if (deeplApiKey) {
    const isFreePlan = process.env['DEEPL_FREE'] === 'true';
    providers.push(new DeepLTranslationProvider(deeplApiKey, isFreePlan));
    console.log(`✓ DeepL: Initialized (${isFreePlan ? 'Free' : 'Pro'} plan)`);
  } else {
    console.log('✗ DeepL: Missing DEEPL_API_KEY');
  }

  // iTranslate
  const itranslateApiKey = process.env['ITRANSLATE_API_KEY'];
  if (itranslateApiKey) {
    providers.push(new ITranslateProvider(itranslateApiKey));
    console.log('✓ iTranslate: Initialized');
  } else {
    console.log('✗ iTranslate: Missing ITRANSLATE_API_KEY');
  }

  if (providers.length === 0) {
    console.log('\nNo providers available. Please set the required environment variables.');
    process.exit(1);
  }

  console.log(`\nRunning ${TEST_CASES.length} test cases across ${providers.length} providers...\n`);
  console.log('-'.repeat(80));

  const allResults: ComparisonResult[] = [];
  const latencyStats: Record<string, number[]> = {};

  for (const testCase of TEST_CASES) {
    console.log(`\n[${testCase.category.toUpperCase()}] "${testCase.text}"`);
    console.log(`  ${testCase.source} → ${testCase.target}`);

    const result: ComparisonResult = {
      testCase,
      results: [],
    };

    for (const provider of providers) {
      try {
        const translation = await provider.translate({
          text: testCase.text,
          sourceLanguage: testCase.source,
          targetLanguage: testCase.target,
        });

        result.results.push({
          provider: provider.name,
          translation: translation.translatedText,
          latencyMs: translation.latencyMs,
        });

        // Track latency stats
        if (!latencyStats[provider.name]) {
          latencyStats[provider.name] = [];
        }
        latencyStats[provider.name]!.push(translation.latencyMs);

        console.log(`  ${provider.name.padEnd(25)} (${translation.latencyMs}ms): ${translation.translatedText}`);
      } catch (error: any) {
        result.results.push({
          provider: provider.name,
          translation: '',
          latencyMs: 0,
          error: error.message,
        });
        console.log(`  ${provider.name.padEnd(25)} ERROR: ${error.message}`);
      }
    }

    allResults.push(result);

    // Small delay between test cases to avoid rate limiting
    await new Promise(resolve => setTimeout(resolve, 500));
  }

  // Print summary
  console.log('\n' + '='.repeat(80));
  console.log('SUMMARY');
  console.log('='.repeat(80));

  console.log('\nLatency Statistics (ms):');
  console.log('-'.repeat(60));
  console.log('Provider'.padEnd(30) + 'Avg'.padStart(10) + 'Min'.padStart(10) + 'Max'.padStart(10));
  console.log('-'.repeat(60));

  for (const [provider, latencies] of Object.entries(latencyStats)) {
    if (latencies.length === 0) continue;
    const avg = Math.round(latencies.reduce((a, b) => a + b, 0) / latencies.length);
    const min = Math.min(...latencies);
    const max = Math.max(...latencies);
    console.log(provider.padEnd(30) + avg.toString().padStart(10) + min.toString().padStart(10) + max.toString().padStart(10));
  }

  // Error summary
  console.log('\nError Summary:');
  console.log('-'.repeat(60));
  const errorCounts: Record<string, number> = {};
  for (const result of allResults) {
    for (const r of result.results) {
      if (r.error) {
        errorCounts[r.provider] = (errorCounts[r.provider] || 0) + 1;
      }
    }
  }

  if (Object.keys(errorCounts).length === 0) {
    console.log('No errors encountered!');
  } else {
    for (const [provider, count] of Object.entries(errorCounts)) {
      console.log(`${provider}: ${count} errors`);
    }
  }

  // Output JSON results for further analysis
  const outputFile = `sxs-results-${new Date().toISOString().replace(/[:.]/g, '-')}.json`;
  const fs = await import('fs');
  fs.writeFileSync(outputFile, JSON.stringify({
    timestamp: new Date().toISOString(),
    testCases: TEST_CASES.length,
    providers: providers.map(p => p.name),
    results: allResults,
    latencyStats: Object.fromEntries(
      Object.entries(latencyStats).map(([k, v]) => [k, {
        avg: Math.round(v.reduce((a, b) => a + b, 0) / v.length),
        min: Math.min(...v),
        max: Math.max(...v),
        samples: v.length,
      }])
    ),
  }, null, 2));

  console.log(`\nDetailed results saved to: ${outputFile}`);
}

// Run the comparison
runComparison().catch(console.error);
