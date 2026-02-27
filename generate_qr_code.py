import qrcode

data = "https://github.com/dennisseah/agent-identity"

img = qrcode.make(data)

# Save the image to a file
with open("docs/images/barcode.png", "wb") as f:
    img.save(f)
