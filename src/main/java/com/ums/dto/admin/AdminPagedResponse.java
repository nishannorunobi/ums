package com.ums.dto.admin;

import java.util.List;

public class AdminPagedResponse {
    private List<AdminUserResponse> users;
    private int page;
    private int size;
    private long total;
    private int totalPages;

    public AdminPagedResponse(List<AdminUserResponse> users, int page, int size, long total) {
        this.users = users;
        this.page = page;
        this.size = size;
        this.total = total;
        this.totalPages = (int) Math.ceil((double) total / size);
    }

    public List<AdminUserResponse> getUsers() { return users; }
    public int getPage() { return page; }
    public int getSize() { return size; }
    public long getTotal() { return total; }
    public int getTotalPages() { return totalPages; }
}
