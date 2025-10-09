import express from "express";

import {
  init as exchangeInit,
  getAccounts,
  setAccountBalance,
  getRates,
  setRate,
  getLog,
  exchange,
} from "./exchange.js";

await exchangeInit();

const app = express();
const port = process.env.PORT || 3000;

app.use(express.json());

// HEALTH CHECK endpoint
app.get("/health", (req, res) => {
  try {
    const accounts = getAccounts();
    const rates = getRates();
    
    if (accounts && rates) {
      res.status(200).json({ status: "healthy", timestamp: new Date().toISOString() });
    } else {
      res.status(503).json({ status: "unhealthy", message: "State not initialized" });
    }
  } catch (error) {
    res.status(503).json({ status: "unhealthy", error: error.message });
  }
});

// ACCOUNT endpoints

app.get("/accounts", (req, res) => {
  res.json(getAccounts());
});

app.put("/accounts/:id/balance", (req, res) => {
  const accountId = req.params.id;
  const { balance } = req.body;

  if (!accountId || !balance) {
    return res.status(400).json({ error: "Malformed request" });
  }

  setAccountBalance(accountId, Number(balance));
  res.json(getAccounts());
});

// RATE endpoints

app.get("/rates", (req, res) => {
  res.json(getRates());
});

app.put("/rates", (req, res) => {
  const { baseCurrency, counterCurrency, rate } = req.body;

  if (!baseCurrency || !counterCurrency || !rate) {
    return res.status(400).json({ error: "Malformed request" });
  }
  const newRateRequest = { baseCurrency, counterCurrency, rate: Number(rate) };
  setRate(newRateRequest);

  res.json(getRates());
});

// LOG endpoint

app.get("/log", (req, res) => {
  res.json(getLog());
});

// EXCHANGE endpoint

app.post("/exchange", async (req, res) => {
  const {
    baseCurrency,
    counterCurrency,
    baseAccountId,
    counterAccountId,
    baseAmount,
  } = req.body;

  if (
    !baseCurrency ||
    !counterCurrency ||
    !baseAccountId ||
    !counterAccountId ||
    !baseAmount
  ) {
    return res.status(400).json({ error: "Malformed request" });
  }

  const result = await exchange({
    baseCurrency,
    counterCurrency,
    baseAccountId,
    counterAccountId,
    baseAmount: Number(baseAmount),
  });

  res.status(result.ok ? 200 : 500).json(result);
});

app.listen(port, () => {
  console.log(`[worker ${process.pid}] Exchange API listening on port ${port}`);
});

export default app;
