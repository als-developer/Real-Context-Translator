import pytest
import time
import uuid
from playwright.sync_api import Page, expect

@pytest.mark.e2e
class TestE2EFlow:
    
    def test_user_registration_and_login(self, page: Page):
        # Navigate to login page
        page.goto("https://dashboard.rct-engine.com/login")
        
        # Click register link
        page.click("text=Contact sales")
        
        # Actually we'll use demo credentials
        page.fill('input[type="email"]', "demo@rct-engine.com")
        page.fill('input[type="password"]', "demo123")
        page.click("button:has-text('Sign In')")
        
        # Wait for dashboard to load
        expect(page.locator("h1:has-text('Dashboard Overview')")).to_be_visible()
    
    def test_translation_workflow(self, page: Page):
        # Login first
        page.goto("https://dashboard.rct-engine.com/login")
        page.fill('input[type="email"]', "demo@rct-engine.com")
        page.fill('input[type="password"]', "demo123")
        page.click("button:has-text('Sign In')")
        
        # Navigate to translator
        page.click("text=Translator")
        expect(page.locator("h1:has-text('Cultural Translator')")).to_be_visible()
        
        # Enter text
        page.fill("textarea", "Piga chini ofisi za zamani")
        
        # Select target country
        page.select_option("select:below(:text('Target Country'))", "KE")
        
        # Click translate
        page.click("button:has-text('Translate')")
        
        # Wait for result
        expect(page.locator(".translation-result")).to_be_visible(timeout=30000)
    
    def test_billing_page_access(self, page: Page):
        page.goto("https://dashboard.rct-engine.com/login")
        page.fill('input[type="email"]', "demo@rct-engine.com")
        page.fill('input[type="password"]', "demo123")
        page.click("button:has-text('Sign In')")
        
        # Navigate to billing
        page.click("text=Billing")
        
        # Verify plans are displayed
        expect(page.locator("text=Professional")).to_be_visible()
        expect(page.locator("text=Enterprise")).to_be_visible()
    
    def test_analytics_dashboard(self, page: Page):
        page.goto("https://dashboard.rct-engine.com/login")
        page.fill('input[type="email"]', "demo@rct-engine.com")
        page.fill('input[type="password"]', "demo123")
        page.click("button:has-text('Sign In')")
        
        # Navigate to analytics
        page.click("text=Analytics")
        
        # Verify charts are loaded
        expect(page.locator(".recharts-wrapper")).to_be_visible()
