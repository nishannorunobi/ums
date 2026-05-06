package com.ums.dto.admin;

public class AdminStatsResponse {
    private long total;
    private long enabled;
    private long disabled;
    private long newToday;
    private long newThisWeek;
    private long newThisMonth;

    public long getTotal() { return total; }
    public void setTotal(long total) { this.total = total; }
    public long getEnabled() { return enabled; }
    public void setEnabled(long enabled) { this.enabled = enabled; }
    public long getDisabled() { return disabled; }
    public void setDisabled(long disabled) { this.disabled = disabled; }
    public long getNewToday() { return newToday; }
    public void setNewToday(long newToday) { this.newToday = newToday; }
    public long getNewThisWeek() { return newThisWeek; }
    public void setNewThisWeek(long newThisWeek) { this.newThisWeek = newThisWeek; }
    public long getNewThisMonth() { return newThisMonth; }
    public void setNewThisMonth(long newThisMonth) { this.newThisMonth = newThisMonth; }
}
