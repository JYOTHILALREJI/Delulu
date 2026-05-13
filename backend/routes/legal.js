const express = require('express');
const router = express.Router();
const path = require('path');

// Mock content for public URLs (Google/Apple requirement)
// In production, these should serve full HTML pages or be redirected to a static host.

router.get('/privacy-policy', (req, res) => {
  res.send(`
    <html>
      <head>
        <title>Delulu - Privacy Policy</title>
        <style>
          body { font-family: sans-serif; padding: 40px; line-height: 1.6; max-width: 800px; margin: auto; background: #111318; color: #E2E2E8; }
          h1 { color: #ECB2FF; }
          h2 { color: #ECB2FF; border-bottom: 1px solid #333; padding-bottom: 10px; }
          .last-updated { color: #9D8BA0; font-size: 0.9em; }
        </style>
      </head>
      <body>
        <h1>Privacy Policy</h1>
        <p class="last-updated">Last Updated: May 13, 2026</p>
        <p>Welcome to Delulu. Your privacy is important to us. This policy explains how we collect, use, and protect your data.</p>
        
        <h2>1. Data We Collect</h2>
        <p>We collect account information (name, email, DOB), profile media, location data (for matching), and communication data (messages, voice notes).</p>
        
        <h2>2. Use of Data</h2>
        <p>We use your data to facilitate matches, enable realtime interactions, process subscriptions, and ensure platform safety.</p>
        
        <h2>3. Security</h2>
        <p>We use industry-standard encryption to protect your data during transmission and storage.</p>
        
        <h2>4. Your Rights</h2>
        <p>You can access, modify, or delete your data via the app settings. Account deletion removes your data from our active systems.</p>
        
        <p>Questions? Contact us at support@delulu.app</p>
      </body>
    </html>
  `);
});

router.get('/terms', (req, res) => {
  res.send(`
    <html>
      <head>
        <title>Delulu - Terms & Conditions</title>
        <style>
          body { font-family: sans-serif; padding: 40px; line-height: 1.6; max-width: 800px; margin: auto; background: #111318; color: #E2E2E8; }
          h1 { color: #ECB2FF; }
          h2 { color: #ECB2FF; border-bottom: 1px solid #333; padding-bottom: 10px; }
          .last-updated { color: #9D8BA0; font-size: 0.9em; }
        </style>
      </head>
      <body>
        <h1>Terms & Conditions</h1>
        <p class="last-updated">Last Updated: May 13, 2026</p>
        
        <h2>1. Eligibility</h2>
        <p>You must be at least 18 years old to use Delulu. You agree to provide accurate information and not impersonate others.</p>
        
        <h2>2. Conduct</h2>
        <p>No harassment, hate speech, or explicit illegal content. Scams and solicitation are strictly prohibited.</p>
        
        <h2>3. Subscriptions</h2>
        <p>Rizz+ subscriptions auto-renew through your app store account. You can cancel at any time via your device settings.</p>
        
        <h2>4. Safety</h2>
        <p>User interactions are at your own risk. Use our reporting and blocking tools to maintain a safe experience.</p>
        
        <h2>5. Termination</h2>
        <p>We reserve the right to terminate accounts that violate these terms without refund.</p>
      </body>
    </html>
  `);
});

module.exports = router;
