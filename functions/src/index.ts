import { onCall, HttpsError } from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
import axios from "axios";
import * as iconv from "iconv-lite";
import * as cheerio from "cheerio";

admin.initializeApp();

const url =
  "https://www.appaweb.appa.pr.gov.br/appaweb/pesquisa.aspx?WCI=relLineUpRetroativo";

function parseRetroativo(html: string): any[] {
  const $ = cheerio.load(html);
  const lineupData: any[] = [];
  const statusesDesejados = ["ATRACADOS", "PROGRAMADOS", "ESPERADOS", "AO LARGO"];

  // Procura todos os <th colspan> que são títulos de seção
  $("th[colspan]").each((_, th) => {
    let currentStatus = $(th).text().trim().toUpperCase();

    if (currentStatus.includes("REATRACAÇÃO")) return;
    if (currentStatus.includes("ESPERADA")) currentStatus = "ESPERADOS";
    if (currentStatus.includes("LARGO")) currentStatus = "AO LARGO";

    if (!statusesDesejados.includes(currentStatus)) return;

    // Pega a tabela onde está esse cabeçalho
    const table = $(th).closest("table");

    // Itera as linhas do corpo da tabela
    table.find("tbody tr").each((_, row) => {
      const cells = $(row).find("td").map((__, td) =>
        $(td).text().replace(/\s+/g, " ").trim()
      ).get();

      if (cells.length === 0) return;

      let navioData: any = { status: currentStatus };

      try {
        if (currentStatus === "ATRACADOS") {
          if (cells.length >= 22) {
            navioData = { status: currentStatus, program: cells[1], berco: cells[3], navio: cells[4], produto: cells[12], eta: cells[13], sentido: cells[9], qtd: parseFloat(cells[18].replace(/\./g, "").replace(",", ".")) || 0 };
          }
        } else if (currentStatus === "PROGRAMADOS") {
          if (cells.length >= 17) {
            navioData = { status: currentStatus, program: cells[1], berco: cells[3], navio: cells[4], produto: cells[14], eta: cells[15], sentido: cells[11], qtd: parseFloat(cells[19].replace(/\./g, "").replace(",", ".")) || 0 };
          }
        } else if (currentStatus === "ESPERADOS") {
          if (cells.length >= 18) {
            navioData = { status: currentStatus, program: cells[1], berco: cells[3], navio: cells[4], produto: cells[11], eta: cells[12], sentido: cells[8], qtd: parseFloat(cells[15].replace(/\./g, "").replace(",", ".")) || 0 };
          }
        } else if (currentStatus === "AO LARGO") {
          if (cells.length >= 18 && cells.length <= 19) {
            navioData = { status: currentStatus, program: cells[1], berco: cells[3], navio: cells[4], produto: cells[11], eta: cells[12], sentido: cells[8], qtd: parseFloat(cells[16].replace(/\./g, "").replace(",", ".")) || 0 };
          } else if (cells.length >= 21) {
            navioData = { status: currentStatus, program: cells[1], berco: cells[3], navio: cells[4], produto: cells[12], eta: cells[13], sentido: cells[9], qtd: parseFloat(cells[18].replace(/\./g, "").replace(",", ".")) || 0 };
          }
        }

        if (navioData.navio && navioData.navio !== "") {
          if (navioData.berco === "201") {
            lineupData.push(navioData);
          } else if (navioData.berco === "212" || navioData.berco === "213" || navioData.berco === "214") {
            if (navioData.produto === "SOJA" || navioData.produto === "MILHO") {
              lineupData.push(navioData);
            }
          }
        }
      } catch (e) {
        console.error(`Erro ao processar linha na seção ${currentStatus}`, e);
      }
    });
  });

  return lineupData;
}

export const getLineupData = onCall({ memory: "1GiB", timeoutSeconds: 120 }, async (request) => {
  // Se o usuário não estiver autenticado, o 'request.auth' será nulo.
  if (!request.auth) {
    // --- CORREÇÃO AQUI ---
    // Removemos o prefixo 'functions.https.'
    throw new HttpsError(
      "unauthenticated",
      "A função só pode ser chamada por usuários autenticados."
    );
  }

  console.log(`Função chamada pelo usuário: ${request.auth.uid}`);

  try {
    // ... (a lógica do axios e do parseRetroativo continua a mesma)
    const { data } = await axios.get(url, {
      responseType: 'arraybuffer',
      headers: { 'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/109.0.0.0 Safari/537.36' },
    });
    const decodedData = iconv.decode(Buffer.from(data), 'windows-1252');
    const lineupData = parseRetroativo(decodedData);
    console.log(`Dados extraídos: ${lineupData.length} itens.`);
    return lineupData;

  } catch (error) {
    console.error("Erro no scraping:", error);
    // --- CORREÇÃO AQUI ---
    // Removemos o prefixo 'functions.https.'
    throw new HttpsError(
      "internal",
      "Ocorreu um erro ao processar a solicitação."
    );
  }
});