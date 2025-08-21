import { onRequest } from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
import axios from "axios";
import cors = require("cors");
import * as iconv from "iconv-lite";

const corsHandler = cors({ origin: true });
admin.initializeApp();

const urls = {
    corex: "https://www.appaweb.appa.pr.gov.br/appaweb/pesquisa.aspx?WCI=relEmitirLineUpCorex&Criterio=PageSize%3D20&sqlFLG_STATUS=0",
    retroativo: "https://www.appaweb.appa.pr.gov.br/appaweb/pesquisa.aspx?WCI=relLineUpRetroativo",
};

// --- SUA FUNÇÃO parseCorex (que funcionou) ---
// Adaptei apenas os índices das colunas para os valores corretos
function parseCorex(html: string): any[] {
    const lineupData: any[] = [];
    let currentStatus = "";
    const cellRegex = /<(td|th) .*?>(.*?)<\/\1>/gs;
    const rows = html.split(/<\/?tr.*?>/g);

    for (const rowHtml of rows) {
        if (!rowHtml.trim()) continue;
        const cells = Array.from(rowHtml.matchAll(cellRegex), (match) => match[2].trim().replace(/&nbsp;/g, ''));
        if (cells.length === 0) continue;

        if (cells.length === 1 && /^[A-Z\s-]+$/.test(cells[0])) {
            currentStatus = cells[0];
            if (currentStatus.includes("PRÉ-LINE UP")) currentStatus = "PRÉ-LINE UP";
            continue;
        }
        if (cells.join('').includes('EMBARCAÇÃO') && cells.join('').includes('AGÊNCIA')) continue;

        if (cells.length > 10) {
            let navioData: any = { status: currentStatus };
            try {
                if (currentStatus === 'ATRACADOS') {
                    if (cells.length < 17) continue;
                    navioData = { status: currentStatus, embarcacao: cells[3], produto: cells[7], agencia: cells[8], operador: cells[9], quantidadeMovida: parseFloat(cells[16].replace(/\./g, "").replace(",", ".")) || 0 };
                } else if (currentStatus === 'PROGRAMADOS') {
                    if (cells.length < 15) continue;
                    navioData = { status: currentStatus, embarcacao: cells[3], produto: cells[7], agencia: cells[8], operador: cells[9], quantidadePrevista: parseFloat(cells[14].replace(/\./g, "").replace(",", ".")) || 0 };
                } else if (currentStatus.includes('LINE UP') || currentStatus === 'ANUNCIADOS' || currentStatus === 'PRÉ-LINE UP') {
                    if (cells.length < 16) continue;
                    navioData = { status: currentStatus, embarcacao: cells[3], produto: cells[7], agencia: cells[9], operador: cells[10], quantidadePrevista: parseFloat(cells[13].replace(/\./g, "").replace(",", ".")) || 0 };
                }
                if (navioData.embarcacao && navioData.embarcacao !== '') {
                    lineupData.push(navioData);
                }
            } catch (e) {
                console.log("Erro ao processar linha (Corex):", e);
            }
        }
    }
    return lineupData;
}

// --- NOVA FUNÇÃO parseRetroativo (baseada na sua lógica do Corex) ---
function parseRetroativo(html: string): any[] {
    const lineupData: any[] = [];
    let currentStatus = "";
    const statusesDesejados = ["ATRACADOS", "PROGRAMADOS", "ESPERADOS", "AO LARGO"];
    const cellRegex = /<(td|th) .*?>(.*?)<\/\1>/gs;
    const rows = html.split(/<\/?tr.*?>/g);

    for (const rowHtml of rows) {
        if (!rowHtml.trim()) continue;
        const cells = Array.from(rowHtml.matchAll(cellRegex), (match) => match[2].trim().replace(/&nbsp;/g, ''));
        if (cells.length === 0) continue;

        // Identifica o título da seção (ex: ATRACADOS)
        if (cells.length === 1 && /^[A-Z\s-]+$/.test(cells[0])) {
            let statusText = cells[0];
            if (statusText.includes("PARA REATRACAÇÃO")) {
                currentStatus = "IGNORAR"; // Marcamos para ser ignorada
            } else if (statusText.includes("DESPACHADOS")) {
                currentStatus = "IGNORAR";
            } else if (statusText.includes("APOIO")) {
                currentStatus = "IGNORAR";
            } else {
                currentStatus = statusText; // Mantém os outros (ATRACADOS, PROGRAMADOS)
            }
            currentStatus = statusText;
            continue;
        }

        // Pula a linha do cabeçalho de colunas
        if (cells.join('').includes('Embarcação') && cells.join('').includes('Agência')) {
            continue;
        }

        // Se for uma linha de dados e o status for um dos que queremos
        if (cells.length > 10 && statusesDesejados.includes(currentStatus)) {
            let navioData: any = { status: currentStatus };
            try {
                // Mapeamento de colunas específico para cada seção do RETROATIVO
                if (currentStatus === 'ATRACADOS') {
                    if (cells.length < 16) continue;
                    navioData = { status: currentStatus, berco: cells[3], navio: cells[4], produto: cells[12], eta: cells[13], sentido: cells[10], qtd: parseFloat(cells[18].replace(/\./g, "").replace(",", ".")) || 0 };
                } else if (currentStatus === 'PROGRAMADOS') {
                    if (cells.length < 17) continue;
                    navioData = { status: currentStatus, berco: cells[3], navio: cells[4], produto: cells[15], eta: cells[15], sentido: cells[11], qtd: parseFloat(cells[19].replace(/\./g, "").replace(",", ".")) || 0 };
                } else if (currentStatus === 'AO LARGO') {
                    if (cells.length < 12) continue;
                    navioData = { status: currentStatus, berco: cells[3], navio: cells[4], produto: cells[11], eta: cells[12], sentido: cells[8], qtd: parseFloat(cells[16].replace(/\./g, "").replace(",", ".")) || 0 };
                } else if (currentStatus === 'ESPERADOS') {
                    if (cells.length < 12) continue;
                    navioData = { status: currentStatus, berco: cells[3], navio: cells[4], produto: cells[11], eta: cells[12], sentido: cells[8], qtd: parseFloat(cells[15].replace(/\./g, "").replace(",", ".")) || 0 };
                }

                if (navioData.navio && navioData.navio !== '') {
                    if (navioData.berco === '201' || navioData.berco === '212' || navioData.berco === '213' || navioData.berco === '214') {
                        lineupData.push(navioData);
                    }
                }
            } catch (e) {
                console.log(`Erro ao processar linha (Retroativo) na seção ${currentStatus}:`, e);
            }
        }
    }
    return lineupData;
}


// --- FUNÇÃO PRINCIPAL ---
export const getLineupData = onRequest((request, response) => {
    corsHandler(request, response, async () => {
        const type = request.query.type as 'corex' | 'retroativo';
        if (!type || !urls[type as keyof typeof urls]) {
            response.status(400).send("Parâmetro 'type' inválido. Use 'corex' ou 'retroativo'.");
            return;
        }
        try {
            const { data } = await axios.get(urls[type as keyof typeof urls], {
                responseType: 'arraybuffer',
                headers: { 'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/109.0.0.0 Safari/537.36' },
            });
            const decodedData = iconv.decode(Buffer.from(data), 'windows-1252');

            let lineupData: any[] = [];
            if (type === "corex") {
                lineupData = parseCorex(decodedData);
            } else if (type === "retroativo") {
                lineupData = parseRetroativo(decodedData);
            }

            console.log(`Dados extraídos para '${type}': ${lineupData.length} itens.`);
            response.status(200).json(lineupData);

        } catch (error) {
            console.error("Erro no scraping:", error);
            response.status(500).send("Ocorreu um erro ao processar a solicitação.");
        }
    });
});