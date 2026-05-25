# EasyOCR Alternative & PDF-to-DOCX Workflow

## When to Use
- Tesseract OCR not installed
- Need Python-only solution (no system dependencies)
- Scanned PDFs requiring OCR extraction

## Installation
```bash
pip install easyocr python-docx PyMuPDF Pillow
```

## PDF to DOCX with OCR

```python
import fitz  # PyMuPDF
import easyocr
from docx import Document
from PIL import Image
import os
import tempfile

def pdf_to_docx_ocr(pdf_path, output_path, pages=None, min_confidence=0.3):
    """Convert scanned PDF to editable DOCX using OCR."""
    
    # Initialize EasyOCR (Chinese + English)
    reader = easyocr.Reader(['ch_sim', 'en'], gpu=False)
    
    doc = fitz.open(pdf_path)
    word_doc = Document()
    
    # Determine page range
    if pages is None:
        pages = range(len(doc))
    
    for page_num in pages:
        if page_num >= len(doc):
            break
            
        page = doc[page_num]
        
        # Render page to image
        pix = page.get_pixmap()
        
        # Save temp image
        temp_dir = tempfile.gettempdir()
        temp_path = os.path.join(temp_dir, f"ocr_page_{page_num}.png")
        pix.save(temp_path)
        
        # Perform OCR
        results = reader.readtext(temp_path)
        
        # Add to Word document
        if page_num > 0:
            word_doc.add_page_break()
        word_doc.add_heading(f'Page {page_num + 1}', level=1)
        
        for detection in results:
            text = detection[1]
            confidence = detection[2]
            if confidence >= min_confidence:
                word_doc.add_paragraph(text)
        
        # Cleanup temp file
        os.remove(temp_path)
    
    word_doc.save(output_path)
    doc.close()
    return output_path

# Usage
pdf_to_docx_ocr(
    "scanned_document.pdf",
    "output.docx",
    pages=range(4),  # First 4 pages
    min_confidence=0.3
)
```

## Performance Notes

| Setting | Speed | Accuracy |
|---------|-------|----------|
| CPU, single page | ~10s | Good for printed text |
| GPU, single page | ~2s | Good for printed text |
| Chinese text | Slower | Varies (0.3-0.97 confidence) |

## Known Limitations

1. **Speed**: Much slower than Tesseract on CPU
2. **Chinese accuracy**: Varies by document quality
3. **Handwriting**: Poor recognition
4. **Complex layouts**: May lose structure

## Color-Based Text Filtering

For documents with mixed colors (black text + red annotations):

```python
from PIL import Image

def filter_by_color(input_path, output_path, remove_color='red'):
    """Remove text of specified color from image."""
    img = Image.open(input_path).convert('RGB')
    pixels = img.load()
    width, height = img.size
    
    for x in range(width):
        for y in range(height):
            r, g, b = pixels[x, y]
            
            if remove_color == 'red':
                # Remove red text (high R, low G/B)
                if r > 150 and g < 100 and b < 100:
                    pixels[x, y] = (255, 255, 255)
            elif remove_color == 'blue':
                # Remove blue text (high B, low R/G)
                if b > 150 and r < 100 and g < 100:
                    pixels[x, y] = (255, 255, 255)
    
    img.save(output_path)
```

### Limitations of Color Filtering
- Thresholds require manual tuning per document
- Anti-aliased text edges cause partial removal
- Scanned documents may have color artifacts
- Consider manual post-processing for critical documents

## Troubleshooting

| Issue | Solution |
|-------|----------|
| "tesseract is not installed" | Use EasyOCR instead |
| Slow processing | Enable GPU or reduce page count |
| Low confidence scores | Try preprocessing (contrast, sharpen) |
| Missing text | Check if PDF is image-based (no selectable text)