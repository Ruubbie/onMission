// Record shapes from api/openapi.yaml. Unknown fields are kept untouched (newer apps may add some).

export const COLLECTIONS = ["tasks", "checklists", "partners", "gifts", "budget", "sellItems", "packing", "notes", "documents", "contacts", "newsletters", "settings"] as const;
export type Collection = (typeof COLLECTIONS)[number];

export interface Rec<T = Record<string, unknown>> {
  id: string;
  collection: Collection;
  updatedAt: string;
  deletedAt?: string | null;
  data: T;
}

export interface Link { collection: Collection; id: string; label?: string }
interface Common { links?: Link[]; tags?: string[]; fileIds?: string[]; order?: number; [k: string]: unknown }

export const AREAS = ["visa", "admin", "finance", "support", "newsletter", "selling", "packing", "housing", "health", "insurance", "church", "travel", "ywam", "personal", "other"] as const;
export type Area = (typeof AREAS)[number];

export const TASK_STATUS = ["todo", "doing", "waiting", "done", "skipped"] as const;
export const PRIORITY = ["low", "normal", "high"] as const;
export interface Task extends Common {
  title: string; notes?: string; status: (typeof TASK_STATUS)[number]; area?: Area; priority?: (typeof PRIORITY)[number];
  dueDate?: string; remindAt?: string; completedAt?: string; checklistId?: string; parentTaskId?: string; waitingOn?: string; sourceUrl?: string;
}

export const PHASES = ["now", "before-departure", "departure-week", "arrival", "ongoing"] as const;
export interface Checklist extends Common { title: string; description?: string; area?: Area; phase?: (typeof PHASES)[number]; archived?: boolean }

export const STAGES = ["idea", "to-ask", "asked", "thinking", "committed", "giving", "declined", "paused"] as const;
export interface Partner extends Common {
  name: string; contactId?: string; email?: string; phone?: string; church?: string; stage: (typeof STAGES)[number];
  monthlyCents?: number; oneOffCents?: number; currency?: string; startDate?: string; prayer?: boolean; newsletter?: boolean;
  lastContactAt?: string; nextFollowUp?: string; thankedAt?: string; notes?: string;
}

export interface Gift extends Common {
  partnerId?: string; amountCents: number; currency: string; date: string; recurring?: boolean; via?: string; thankedAt?: string; notes?: string;
}

export const BUDGET_KIND = ["income", "expense", "saving"] as const;
export const RECURRENCE = ["once", "monthly", "yearly"] as const;
export interface BudgetEntry extends Common {
  kind: (typeof BUDGET_KIND)[number]; label: string; category?: string; amountCents: number; currency: string;
  recurrence?: (typeof RECURRENCE)[number]; date?: string; phase?: "setup" | "monthly"; paid?: boolean; notes?: string;
}

export const SELL_STATUS = ["decide", "to-list", "listed", "reserved", "sold", "given-away", "keep", "store"] as const;
export interface SellItem extends Common {
  name: string; status: (typeof SELL_STATUS)[number]; askingCents?: number; soldCents?: number; currency?: string; platform?: string;
  listingUrl?: string; buyer?: string; pickupDate?: string; location?: string; notes?: string;
}

export const BAGS = ["checked", "carry-on", "personal", "ship", "buy-there", "leave"] as const;
export interface PackingItem extends Common {
  name: string; bag?: (typeof BAGS)[number]; category?: string; quantity?: number; packed?: boolean; weightGrams?: number; notes?: string;
}

export const NOTE_KINDS = ["note", "prayer", "journal", "meeting", "idea"] as const;
export interface Note extends Common { title: string; body?: string; area?: Area; pinned?: boolean; kind?: (typeof NOTE_KINDS)[number]; answeredAt?: string }

export const DOC_KINDS = ["passport", "visa", "insurance", "ticket", "id", "bank", "medical", "diploma", "reference", "contract", "receipt", "letter", "other"] as const;
export interface Doc extends Common {
  title: string; kind: (typeof DOC_KINDS)[number]; fileId?: string; fileName?: string; mimeType?: string; sizeBytes?: number; sha256?: string;
  number?: string; issuedAt?: string; expiresAt?: string; offline?: boolean; notes?: string;
}

export interface Contact extends Common { name: string; role?: string; organisation?: string; email?: string; phone?: string; address?: string; notes?: string }

export const NEWS_STATUS = ["idea", "draft", "ready", "sent"] as const;
export interface Newsletter extends Common {
  title: string; number?: number; status: (typeof NEWS_STATUS)[number]; plannedDate?: string; sentAt?: string; body?: string; webUrl?: string; notes?: string;
}

export interface Setting {
  key: string; departureDate?: string; supportTargetMonthlyCents?: number; supportMinimumMonthlyCents?: number; currency?: string; nzdPerEur?: number; [k: string]: unknown;
}

export const MAIN_SETTINGS_ID = "60a98c2f-4004-58e7-bcc2-c88a62377933";
