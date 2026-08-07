require("dotenv").config();

const express = require("express");
const multer = require("multer");
const FormData = require("form-data");
const axios = require("axios");
const cors = require("cors");

const app = express();

app.use(cors());

const upload = multer({
  storage: multer.memoryStorage(),
});

app.get("/", (req, res) => {
  res.send("ImageKit Upload Server Running");
});

app.post("/upload", upload.single("image"), async (req, res) => {
  try {
    if (!req.file) {
      return res.status(400).json({
        success: false,
        message: "No image uploaded",
      });
    }

    const form = new FormData();

    form.append("file", req.file.buffer, req.file.originalname);
    form.append("fileName", Date.now() + "-" + req.file.originalname);

    const response = await axios.post(
      "https://upload.imagekit.io/api/v1/files/upload",
      form,
      {
        headers: {
          ...form.getHeaders(),
          Authorization:
            "Basic " +
            Buffer.from(
              process.env.IMAGEKIT_PRIVATE_KEY + ":"
            ).toString("base64"),
        },
      }
    );

    res.json({
      success: true,
      url: response.data.url,
      fileId: response.data.fileId,
    });
  } catch (e) {
    console.error(e.response?.data || e);

    res.status(500).json({
      success: false,
      error: e.response?.data || e.message,
    });
  }
});

const PORT = process.env.PORT || 3000;

app.listen(PORT, () => {
  console.log(`Server running on ${PORT}`);
});