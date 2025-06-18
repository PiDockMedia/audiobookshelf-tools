# DATAFLOW: Test Harness for AI Audiobook Organizer (always in sync with run_all_tests.sh)

1. Clean Test Environment
   - If --clean is specified, remove the entire test output directory, including input, output, and tracking DB.

2. Test Data Generation
   - Generate a variety of test audiobook folders and files in the input directory.
   - Create audio files (optionally with TTS), embed metadata, and add supporting files (cover, description, NFO).
   - Ensure all test data is copyright-safe and reproducible.

3. Simulated AI Bundle Generation
   - Write a valid, single-line JSONL file (ai_input.jsonl) for all test books, with minimal folder paths.
   - This bundle simulates the output of an AI metadata extraction step.

4. Pause for AI Step (Optional)
   - If --pause is specified, pause after AI bundle generation for manual or automated AI response injection.
   - Allows for real or simulated AI integration.

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

---

## Summary
- Input: Synthetic, controlled test data
- Pause: Optional step for AI response injection (manual or automated)
- Output: Organized test output, logs, and validation of the full pipeline
- Key steps: Test data generation → AI bundle & pause → AI response injection → Organization → Validation 