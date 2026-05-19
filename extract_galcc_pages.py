import os
import pypdfium2 as pdfium

pdf_path = r"d:\LOIC\Logiciel LCC 2.0\LCC sentinel 2\assets\img\plans\GaLCC.pdf"
out_dir = r"d:\LOIC\Logiciel LCC 2.0\LCC sentinel 2\assets\img\plans"

pdf = pdfium.PdfDocument(pdf_path)
count = len(pdf)
print(f"pages={count}")

# ~300 DPI equivalent (72 * 4.1667)
scale = 4.1667
for i in range(count):
    page = pdf[i]
    bitmap = page.render(scale=scale)
    pil = bitmap.to_pil()
    out_path = os.path.join(out_dir, f"GaLCC_page_{i+1:02d}.png")
    pil.save(out_path, format="PNG", optimize=True)
    print(out_path)
