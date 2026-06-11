const express = require('express');
const cors = require('cors');
const axios = require('axios');
require('dotenv').config();

const app = express();
app.use(cors());
app.use(express.json());

const PORT = process.env.PORT || 3000;

app.post('/v1/generate', async (req, res) => {
  const { prompt, provider } = req.body || {};
  if (!prompt) return res.status(400).json({ error: 'missing prompt' });

  // 默认使用华为（可通过 provider 指定 deepseek）
  try {
    if (!provider || provider === 'huawei') {
      const apiKey = process.env.HW_API_KEY;
      const endpoint = process.env.HW_ENDPOINT;
      if (!apiKey || !endpoint) return res.status(500).json({ error: 'huawei not configured' });

      // 示例：向华为模型服务发起请求（根据真实 API 适配 body 与 headers）
      const resp = await axios.post(endpoint, { prompt }, { headers: { Authorization: `Bearer ${apiKey}` } });
      return res.json({ result: resp.data?.result || resp.data });
    } else if (provider === 'deepseek') {
      const apiKey = process.env.DS_API_KEY;
      const endpoint = process.env.DS_ENDPOINT;
      if (!apiKey || !endpoint) return res.status(500).json({ error: 'deepseek not configured' });

      const resp = await axios.post(endpoint, { prompt }, { headers: { Authorization: `Bearer ${apiKey}` } });
      return res.json({ result: resp.data?.result || resp.data });
    }
    return res.status(400).json({ error: 'unknown provider' });
  } catch (e) {
    console.error('proxy error', e && e.toString());
    return res.status(500).json({ error: 'proxy failure', detail: e && e.toString() });
  }
});

app.listen(PORT, () => console.log(`AI proxy listening on ${PORT}`));
