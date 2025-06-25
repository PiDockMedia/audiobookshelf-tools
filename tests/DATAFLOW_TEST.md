# DATAFLOW: Test Harness for AI Audiobook Organizer (always in sync with run_all_tests.sh)

**NOTE:** Always run the test harness from the project root as './tests/run_all_tests.sh'. Running from any other directory may cause errors or incorrect test data placement.

1. Clean Test Environment
   - If --clean is specified, remove the entire test output directory at tests/test-audiobooks.

2. Test Data Generation
   - Generate a variety of test audiobook folders and files in the input directory.
   - Create audio files (optionally with TTS), embed metadata, and add supporting files (cover, description, NFO).
   - Ensure all test data is copyright-safe and reproducible.
   - Ensure all test data tries to cover all the most common file and folder formats and naming conventions we encounter. 

3. AI Bundle Generation
   - The script generates the AI bundle (ai_input.jsonl and prompt.md) in the input/ai_bundles/pending directory as in production.
   - For full-pipeline tests, let the script generate this file naturally.
   - For organization-only tests, you may inject a simulated AI response file to skip the AI analysis step.

4. Pause for AI Step (Optional)
   - If --pause is specified, pause after AI bundle generation for manual or automated AI response injection.
   - Allows for real or simulated AI integration.
   - **CRITICAL: This pause functionality must be preserved!** It enables manual AI response injection and debugging.
   - Pause points occur:
     * After test data generation (for inspection)
     * Before organization step (for AI response injection)
     * Within organize_audiobooks.sh at key processing steps

5. Organization Step
   - Run the main organizer script to process the AI responses and organize the test books into the output directory.
   - Validate that the output structure matches expectations.

6. Validation & Logging
   - Log all actions and results to a timestamped log file in tests/logs/.
   - Report success if all steps complete and output matches expectations; log errors otherwise.

7. Test DB Handling
   - The tracking DB is created in the input folder and destroyed with --clean.

8. Sync with Documentation
   - These steps are always kept in sync with the comments at the top of run_all_tests.sh. Any change to the script's logic must be reflected here.

## AI Bundle Format Requirements

- The AI bundle (`ai_input.jsonl`) **must** be in valid JSONL format: one single-line JSON object per line.
- Do **not** use pretty-printed or multi-line JSON.
- The `input_path` field should use only the minimal folder path (e.g., `"Austen, Jane/1813 - Pride and Prejudice {Elizabeth Klett}"`), not absolute or test harness paths.

## Troubleshooting AI Bundle Issues

- If `ai_input.jsonl` is overwritten with pretty-printed JSON, check for post-processing steps or scripts that may be modifying the file after test data generation. The file must remain single-line JSONL.

## Automatic Verification Step

After generating the simulated AI bundle, the test harness automatically checks that:
- Every line in `ai_input.jsonl` is valid single-line JSON.
- The number of valid lines matches the number of lines in the file.
- No `input_path` contains absolute or test harness paths.

If any issues are detected, a warning is printed in the test log.

---

## Summary
- Input: Synthetic, controlled test data
- Pause: Optional step for AI response injection (manual or automated)
- Output: Organized test output, logs, and validation of the full pipeline
- Key steps: Test data generation → AI bundle & pause → AI response injection → Organization → Validation 