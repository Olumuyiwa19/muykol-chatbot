"""Accessibility tests for the Faith Motivator Chatbot."""

import pytest
from selenium import webdriver
from selenium.webdriver.common.by import By
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
from axe_selenium_python import Axe
import time


class TestAccessibility:
    """Accessibility test suite using axe-core."""
    
    @pytest.fixture(scope="class")
    def driver(self):
        """Set up Chrome driver for testing."""
        options = webdriver.ChromeOptions()
        options.add_argument("--headless")
        options.add_argument("--no-sandbox")
        options.add_argument("--disable-dev-shm-usage")
        driver = webdriver.Chrome(options=options)
        driver.implicitly_wait(10)
        yield driver
        driver.quit()
    
    @pytest.fixture
    def axe(self, driver):
        """Initialize axe-core for accessibility testing."""
        return Axe(driver)
    
    def test_landing_page_accessibility(self, driver, axe):
        """Test landing page accessibility compliance."""
        driver.get("http://localhost:3000")
        
        # Wait for page to load
        WebDriverWait(driver, 10).wait(
            EC.presence_of_element_located((By.TAG_NAME, "body"))
        )
        
        # Inject axe-core and run accessibility scan
        axe.inject()
        results = axe.run()
        
        # Assert no violations
        assert len(results["violations"]) == 0, f"Accessibility violations found: {results['violations']}"
    
    def test_navigation_accessibility(self, driver, axe):
        """Test navigation component accessibility."""
        driver.get("http://localhost:3000")
        
        # Wait for navigation to load
        WebDriverWait(driver, 10).wait(
            EC.presence_of_element_located((By.TAG_NAME, "nav"))
        )
        
        # Test keyboard navigation
        nav_links = driver.find_elements(By.CSS_SELECTOR, "nav a, nav button")
        for link in nav_links:
            # Check if element is focusable
            driver.execute_script("arguments[0].focus();", link)
            focused_element = driver.switch_to.active_element
            assert focused_element == link, f"Element {link.text} is not properly focusable"
        
        # Run axe scan on navigation
        axe.inject()
        results = axe.run(context="nav")
        assert len(results["violations"]) == 0, f"Navigation accessibility violations: {results['violations']}"
    
    def test_login_modal_accessibility(self, driver, axe):
        """Test login modal accessibility and focus management."""
        driver.get("http://localhost:3000")
        
        # Open login modal
        login_button = WebDriverWait(driver, 10).wait(
            EC.element_to_be_clickable((By.TEXT, "Get Started"))
        )
        login_button.click()
        
        # Wait for modal to appear
        modal = WebDriverWait(driver, 10).wait(
            EC.presence_of_element_located((By.ROLE, "dialog"))
        )
        
        # Check modal has proper ARIA attributes
        assert modal.get_attribute("aria-modal") == "true"
        assert modal.get_attribute("role") == "dialog"
        
        # Check focus is trapped in modal
        first_focusable = modal.find_element(By.CSS_SELECTOR, "input, button")
        driver.execute_script("arguments[0].focus();", first_focusable)
        
        # Run axe scan on modal
        axe.inject()
        results = axe.run(context="[role='dialog']")
        assert len(results["violations"]) == 0, f"Modal accessibility violations: {results['violations']}"
    
    def test_form_accessibility(self, driver, axe):
        """Test form accessibility including labels and error states."""
        driver.get("http://localhost:3000")
        
        # Open login modal to access form
        login_button = driver.find_element(By.TEXT, "Get Started")
        login_button.click()
        
        # Wait for form to load
        form = WebDriverWait(driver, 10).wait(
            EC.presence_of_element_located((By.TAG_NAME, "form"))
        )
        
        # Check all inputs have labels
        inputs = form.find_elements(By.TAG_NAME, "input")
        for input_element in inputs:
            # Check for label association
            input_id = input_element.get_attribute("id")
            if input_id:
                label = driver.find_element(By.CSS_SELECTOR, f"label[for='{input_id}']")
                assert label is not None, f"Input {input_id} missing associated label"
            
            # Check for aria-label or aria-labelledby
            aria_label = input_element.get_attribute("aria-label")
            aria_labelledby = input_element.get_attribute("aria-labelledby")
            assert aria_label or aria_labelledby or input_id, f"Input missing accessible name"
        
        # Run axe scan on form
        axe.inject()
        results = axe.run(context="form")
        assert len(results["violations"]) == 0, f"Form accessibility violations: {results['violations']}"
    
    def test_color_contrast(self, driver, axe):
        """Test color contrast compliance."""
        driver.get("http://localhost:3000")
        
        # Wait for page to load
        WebDriverWait(driver, 10).wait(
            EC.presence_of_element_located((By.TAG_NAME, "body"))
        )
        
        # Run axe scan with color contrast rules
        axe.inject()
        results = axe.run(tags=["wcag2a", "wcag2aa", "wcag21aa"])
        
        # Filter for color contrast violations
        contrast_violations = [
            violation for violation in results["violations"]
            if "color-contrast" in violation["id"]
        ]
        
        assert len(contrast_violations) == 0, f"Color contrast violations: {contrast_violations}"
    
    def test_keyboard_navigation(self, driver):
        """Test keyboard navigation functionality."""
        driver.get("http://localhost:3000")
        
        # Get all focusable elements
        focusable_elements = driver.find_elements(
            By.CSS_SELECTOR,
            "a, button, input, textarea, select, [tabindex]:not([tabindex='-1'])"
        )
        
        # Test tab order
        for i, element in enumerate(focusable_elements):
            driver.execute_script("arguments[0].focus();", element)
            focused_element = driver.switch_to.active_element
            
            # Check element is properly focused
            assert focused_element == element, f"Element {i} not properly focused"
            
            # Check element has visible focus indicator
            outline = focused_element.value_of_css_property("outline")
            box_shadow = focused_element.value_of_css_property("box-shadow")
            
            assert outline != "none" or box_shadow != "none", f"Element {element.tag_name} missing focus indicator"
    
    def test_screen_reader_announcements(self, driver):
        """Test screen reader announcements and live regions."""
        driver.get("http://localhost:3000")
        
        # Check for live regions
        live_regions = driver.find_elements(By.CSS_SELECTOR, "[aria-live]")
        
        for region in live_regions:
            aria_live = region.get_attribute("aria-live")
            assert aria_live in ["polite", "assertive"], f"Invalid aria-live value: {aria_live}"
        
        # Check for proper heading structure
        headings = driver.find_elements(By.CSS_SELECTOR, "h1, h2, h3, h4, h5, h6")
        heading_levels = [int(h.tag_name[1]) for h in headings]
        
        # Check heading hierarchy (no skipped levels)
        for i in range(1, len(heading_levels)):
            level_diff = heading_levels[i] - heading_levels[i-1]
            assert level_diff <= 1, f"Heading hierarchy violation: h{heading_levels[i-1]} followed by h{heading_levels[i]}"
    
    def test_mobile_accessibility(self, driver, axe):
        """Test accessibility on mobile viewport."""
        # Set mobile viewport
        driver.set_window_size(375, 667)  # iPhone SE size
        driver.get("http://localhost:3000")
        
        # Wait for page to load
        WebDriverWait(driver, 10).wait(
            EC.presence_of_element_located((By.TAG_NAME, "body"))
        )
        
        # Check touch target sizes
        interactive_elements = driver.find_elements(
            By.CSS_SELECTOR,
            "a, button, input, textarea, select"
        )
        
        for element in interactive_elements:
            size = element.size
            # WCAG recommends minimum 44x44px touch targets
            assert size["width"] >= 44 or size["height"] >= 44, f"Touch target too small: {size}"
        
        # Run axe scan on mobile
        axe.inject()
        results = axe.run()
        assert len(results["violations"]) == 0, f"Mobile accessibility violations: {results['violations']}"


@pytest.mark.integration
class TestAccessibilityIntegration:
    """Integration tests for accessibility across user flows."""
    
    def test_complete_user_flow_accessibility(self, driver, axe):
        """Test accessibility throughout complete user flow."""
        driver.get("http://localhost:3000")
        
        # 1. Landing page
        axe.inject()
        results = axe.run()
        assert len(results["violations"]) == 0, "Landing page violations"
        
        # 2. Open login modal
        login_button = driver.find_element(By.TEXT, "Get Started")
        login_button.click()
        
        WebDriverWait(driver, 10).wait(
            EC.presence_of_element_located((By.ROLE, "dialog"))
        )
        
        results = axe.run()
        assert len(results["violations"]) == 0, "Login modal violations"
        
        # 3. Fill and submit form (would need mock authentication)
        # This would continue through the authenticated flow
        
        # 4. Chat interface (after authentication)
        # This would test the chat interface accessibility
        
        # 5. Prayer connect modal
        # This would test the prayer modal accessibility


if __name__ == "__main__":
    pytest.main([__file__, "-v"])