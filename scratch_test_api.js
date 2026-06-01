async function testSubCategory() {
  try {
    const response = await fetch('https://krishi-backend-123180953109.asia-south1.run.app/api/products/categories/6a0d6b0228bb0a2b352ed8b3/subcategories', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ name: 'TestSub' })
    });
    
    console.log('Status:', response.status);
    console.log('Data:', await response.text());
  } catch (e) {
    console.error('Error:', e.message);
  }
}

testSubCategory();
