import { supabase } from "@/integrations/supabase/client";

export async function generateDocNumber(type: "quote" | "invoice", orgId: string): Promise<string> {
  const prefix = type === "quote" ? "QT" : "INV";
  const year = new Date().getFullYear();
  const like = `${prefix}-${year}-%`;

  const { data, error } = await supabase
    .from("documents")
    .select("doc_number")
    .eq("org_id", orgId)
    .like("doc_number", like)
    .order("doc_number", { ascending: false })
    .limit(1);

  if (error) throw error;

  let next = 1;
  if (data && data.length > 0) {
    const last = data[0].doc_number as string;
    const seq = parseInt(last.split("-").pop() || "0", 10);
    if (!Number.isNaN(seq)) next = seq + 1;
  }
  return `${prefix}-${year}-${String(next).padStart(4, "0")}`;
}
