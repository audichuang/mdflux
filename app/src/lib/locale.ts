
export type Lang = 'en' | 'zh';

// Reactive state for active language, loading from localStorage if present
let currentLang = $state<Lang>(
  (typeof localStorage !== 'undefined' && localStorage.getItem('mdflux_lang') as Lang) || 'en'
);

export function getLang(): Lang {
  return currentLang;
}

export function setLang(lang: Lang) {
  currentLang = lang;
  if (typeof localStorage !== 'undefined') {
    localStorage.setItem('mdflux_lang', lang);
  }
}

const translations: Record<Lang, Record<string, string>> = {
  en: {
    // Header
    ready: 'Ready',
    partial: 'Partial',
    checking_env: 'Checking environment…',
    issues_found: 'Issues found',
    repair: 'Repair',
    intelligence: 'Intelligence',
    diagnostics: 'Diagnostics',
    back: 'Back',

    // Dropzone
    drop_files: 'Drop files or a folder here',
    or: 'or',
    browse_choose: 'browse to choose',
    supported_formats: 'PDF · DOCX · PPTX · XLSX · EPUB · HTML · CSV · JSON · images · audio',

    // Staging
    file_ready: 'file ready',
    files_ready: 'files ready',
    clear_all: 'Clear all',
    add_more: 'Add more — drop files anywhere, or',
    choose_files: 'Choose files…',
    choose_folder: 'Choose folder…',
    save_output_to: 'Save output to',
    next_to_source: 'Next to source',
    one_folder: 'One folder',
    mirror_folders: 'Mirror folders',
    no_folder_chosen: 'No folder chosen — choose one',
    change: 'Change…',
    clean_up: 'Clean up',
    off: 'Off',
    rule_based: 'Rule-based',
    ai: 'AI',
    convert_btn: 'Convert to AI-Ready Markdown',
    ocr_notice_1: '{count} file needs OCR or transcription — expect a longer run, and the engine\'s model loads on first use.',
    ocr_notice_n: '{count} files need OCR or transcription — expect a longer run across the batch, and the engine\'s model loads on first use.',

    // ResultView
    preview: 'Preview',
    source: 'Source',
    split: 'Split',
    changes: 'Changes',
    open_new: 'Open a New File',
    copy: 'Copy',
    copied: 'Copied!',
    save_md: 'Save as .md',
    save_open: 'Save & Open',
    discard: 'Discard',
    cancel: 'Cancel',
    modal_title: 'Open a new file?',
    modal_desc: 'Your current result will be lost unless you save it first.',
    from_format: 'From: {format}',

    // Queue / Summary
    overall_progress: 'Overall progress',
    converting: 'Converting…',
    done: 'Done',
    failed: 'Failed',
    cancelled: 'Cancelled',
    queued: 'Queued',
    cancelling: 'Cancelling…',
    stop_batch_hint: 'Stop the whole batch. Files already finished are kept.',
    conv_complete: 'Conversion Complete',
    retry_failed: 'Retry {count} failed file',
    retry_failed_plural: 'Retry {count} failed files',
    copy_failures: 'Copy failures',
    open_folder: 'Open folder',
    convert_more: 'Convert more files',
    view_btn: 'View',

    // Diagnostics Settings
    output_destination: 'Output destination',
    file_name: 'File name',
    letter_case: 'Letter case',
    open_after_batch: 'Open the output folder when a batch finishes',
    llm_provider: 'LLM Provider',
    save_naming_hint: 'Single files are saved with a Save dialog; this rule applies to batch conversions.',
    naming_tokens_hint: 'Tokens: {stem} name · {ext} format · {date} today. .md is added automatically.',
    naming_case_keep: 'Keep',
    naming_case_lower: 'lowercase',
    naming_case_slug: 'slug-case',
    reveal_folder_desc: 'Reveal the converted files in your file manager after a batch run.'
  },
  zh: {
    // Header
    ready: '就緒',
    partial: '部份就緒',
    checking_env: '正在檢查執行環境…',
    issues_found: '偵測到異常',
    repair: '自動修復',
    intelligence: 'AI 智慧優化',
    diagnostics: '系統診斷',
    back: '返回主畫面',

    // Dropzone
    drop_files: '將檔案或資料夾拖曳至此處',
    or: '或',
    browse_choose: '點擊瀏覽選擇',
    supported_formats: '支援 PDF · DOCX · PPTX · XLSX · EPUB · HTML · CSV · JSON · 圖片 · 語音',

    // Staging
    file_ready: '個檔案已就緒',
    files_ready: '個檔案已就緒',
    clear_all: '清除全部',
    add_more: '新增檔案 — 拖曳至任意處，或',
    choose_files: '選擇檔案…',
    choose_folder: '選擇資料夾…',
    save_output_to: '輸出儲存至',
    next_to_source: '與來源同目錄',
    one_folder: '指定單一資料夾',
    mirror_folders: '鏡像複製目錄結構',
    no_folder_chosen: '未選擇資料夾 — 請選擇一個',
    change: '變更資料夾…',
    clean_up: '內文清理優化',
    off: '關閉',
    rule_based: '規則清理 (離線)',
    ai: 'AI 智慧清理',
    convert_btn: '開始轉換為乾淨 Markdown',
    ocr_notice_1: '有 {count} 個檔案需要進行 OCR 識別或語音轉文字 — 轉換時間會較長，且首次執行需下載模型。',
    ocr_notice_n: '有 {count} 個檔案需要進行 OCR 識別或語音轉文字 — 批次轉換時間會較長，且首次執行需下載模型。',

    // ResultView
    preview: '成品預覽',
    source: 'Markdown 原始碼',
    split: '雙欄對照',
    changes: '優化差異',
    open_new: '開啟新檔案',
    copy: '複製內容',
    copied: '已複製！',
    save_md: '另存為 .md',
    save_open: '儲存並開啟',
    discard: '捨棄變更',
    cancel: '取消',
    modal_title: '是否開啟新檔案？',
    modal_desc: '您目前的轉換結果尚未儲存，若直接開啟新檔，未存檔的變更將會遺失。',
    from_format: '來源格式: {format}',

    // Queue / Summary
    overall_progress: '整體批次進度',
    converting: '正在轉換…',
    done: '已完成',
    failed: '轉換失敗',
    cancelled: '已取消',
    queued: '排隊中',
    cancelling: '正在取消…',
    stop_batch_hint: '停止批次轉換。已經完成轉換的檔案將被保留。',
    conv_complete: '批次轉換完成',
    retry_failed: '重試 {count} 個失敗的檔案',
    retry_failed_plural: '重試 {count} 個失敗的檔案',
    copy_failures: '複製錯誤原因',
    open_folder: '開啟輸出資料夾',
    convert_more: '繼續轉換其他檔案',
    view_btn: '檢視',

    // Diagnostics Settings
    output_destination: '輸出目的地設定',
    file_name: '預設檔案名稱樣板',
    letter_case: '英文大小寫轉換',
    open_after_batch: '批次完成後自動打開資料夾',
    llm_provider: 'AI 模型服務商設定',
    save_naming_hint: '單一檔案轉換時會彈出儲存對話框；此規則僅適用於多檔案批次轉換。',
    naming_tokens_hint: '參數: {stem} 主檔名 · {ext} 原始格式 · {date} 今日日期。系統會自動補上 .md 附檔名。',
    naming_case_keep: '保持原樣',
    naming_case_lower: '全部小寫',
    naming_case_slug: '網址格式 (slug-case)',
    reveal_folder_desc: '轉換完成後，自動在檔案總管中顯露出檔案位置。'
  }
};

export function tr(key: string, vars?: Record<string, string | number>): string {
  const lang = currentLang;
  let text = translations[lang]?.[key] || translations['en']?.[key] || key;
  if (vars) {
    Object.entries(vars).forEach(([k, v]) => {
      text = text.replace(`{${k}}`, String(v));
    });
  }
  return text;
}
